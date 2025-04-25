import { LightningElement, wire, track } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex methods
import getCreatableObjects from '@salesforce/apex/TemplateManagementService.getCreatableObjects';
import getObjectFields from '@salesforce/apex/TemplateManagementService.getObjectFields';

export default class SeederConfiguration extends LightningElement {
    @track isLoading = false;
    @track showObjectSelector = false;
    @track showFieldSelector = false;
    @track selectedObject;
    @track selectedFields = [];
    @track objectOptions = [];
    @track fieldOptions = [];
    @track recordCount = 5;
    @track contextSettings = {
        locale: 'en_US',
        industry: '',
        region: ''
    };
    @track error;

    // Constants
    MAX_FIELDS_PER_OBJECT = 15;
    MAX_TOTAL_RECORDS = 50;

    // Computed property for field configuration
    get disableFieldConfig() {
        return !this.selectedObject;
    }

    // Computed property for field selection label
    get fieldSelectionLabel() {
        return `Select Fields for ${this.selectedObject}`;
    }

    // Computed property for range overflow message
    get rangeOverflowMessage() {
        return `Maximum ${this.MAX_TOTAL_RECORDS} records allowed`;
    }

    // Computed property for selected field values array
    get selectedFieldValues() {
        return this.selectedFields.map(field => field.name);
    }

    // Field columns for datatable
    fieldColumns = [
        { label: 'Field Name', fieldName: 'name', type: 'text' },
        { label: 'Field Type', fieldName: 'type', type: 'text' },
        { label: 'Required', fieldName: 'required', type: 'boolean' }
    ];

    // Sample locale options
    localeOptions = [
        { label: 'English (US)', value: 'en_US' },
        { label: 'English (UK)', value: 'en_GB' },
        { label: 'Spanish', value: 'es' },
        { label: 'French', value: 'fr' },
        { label: 'German', value: 'de' }
    ];

    // Sample industry options
    industryOptions = [
        { label: 'Technology', value: 'Technology' },
        { label: 'Financial Services', value: 'Financial_Services' },
        { label: 'Healthcare', value: 'Healthcare' },
        { label: 'Retail', value: 'Retail' },
        { label: 'Manufacturing', value: 'Manufacturing' }
    ];

    // Sample region options
    regionOptions = [
        { label: 'North America', value: 'North_America' },
        { label: 'Europe', value: 'Europe' },
        { label: 'Asia Pacific', value: 'APAC' },
        { label: 'Latin America', value: 'LATAM' },
        { label: 'Middle East & Africa', value: 'MEA' }
    ];

    connectedCallback() {
        // Initialize with default values
        this.contextSettings = {
            locale: 'en_US',
            industry: '',
            region: ''
        };
        this.recordCount = 5;
    }

    /**
     * Handle Configure Objects button click
     */
    handleConfigureObjects() {
        this.showObjectSelector = true;
        this.loadObjectOptions();
    }

    /**
     * Handle Configure Fields button click
     */
    handleConfigureFields() {
        if (this.selectedObject) {
            this.showFieldSelector = true;
            this.loadFieldOptions();
        }
    }

    /**
     * Load all creatable Salesforce objects
     */
    loadObjectOptions() {
        this.isLoading = true;
        
        getCreatableObjects()
            .then(result => {
                this.objectOptions = result.map(obj => ({
                    label: obj.label,
                    value: obj.value
                }));
            })
            .catch(error => {
                this.handleError(error, 'Error loading objects');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Load fields for selected object
     */
    loadFieldOptions() {
        if (!this.selectedObject) return;
        
        this.isLoading = true;
        
        getObjectFields({ objectName: this.selectedObject })
            .then(result => {
                // Filter out lookup fields, non-updateable fields, and external id fields
                const filteredFields = result.filter(field => {
                    return field.type !== 'Reference' && 
                           field.editable !== false;
                });
                
                // Transform field data for the picklist component
                this.fieldOptions = filteredFields.map(field => ({
                    label: field.label,
                    value: field.name,
                    type: field.type,
                    required: field.required,
                    // Preserve all field attributes for later use
                    attributes: field.attributes || {}
                }));
                
                // Pre-select required fields
                const requiredFieldNames = filteredFields
                    .filter(field => field.required)
                    .map(field => field.name);
                
                // Update selected fields with required fields preselected
                if (requiredFieldNames.length > 0) {
                    this.handleFieldSelection({
                        detail: {
                            value: requiredFieldNames
                        }
                    });
                }
            })
            .catch(error => {
                this.handleError(error, 'Error loading fields');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Handle object selection change
     */
    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedFields = [];
        if (this.selectedObject) {
            this.loadFieldOptions();
        }
    }

    /**
     * Handle field selection change
     */
    handleFieldSelection(event) {
        const selectedValues = event.detail.value;
        
        // Check if we're not exceeding the max fields limit
        if (selectedValues.length > this.MAX_FIELDS_PER_OBJECT) {
            this.showToast(
                'Too many fields selected',
                `Maximum ${this.MAX_FIELDS_PER_OBJECT} fields allowed per object`,
                'error'
            );
            return;
        }
        
        // Find the required fields
        const requiredFields = this.fieldOptions
            .filter(field => field.required)
            .map(field => field.value);
        
        // Ensure all required fields are included
        const missingRequiredFields = requiredFields.filter(
            field => !selectedValues.includes(field)
        );
        
        // If required fields are missing, add them and notify the user
        if (missingRequiredFields.length > 0) {
            const updatedSelection = [...selectedValues, ...missingRequiredFields];
            
            // Update the dual listbox with the corrected selection
            const dualListbox = this.template.querySelector('lightning-dual-listbox');
            if (dualListbox) {
                dualListbox.value = updatedSelection;
            }
            
            this.showToast(
                'Required fields added',
                'Required fields cannot be unselected',
                'info'
            );
            
            // Process the updated selection
            this.processFieldSelection(updatedSelection);
        } else {
            // Process the selection as is
            this.processFieldSelection(selectedValues);
        }
    }

    /**
     * Process the field selection by updating the component state
     */
    processFieldSelection(selectedValues) {
        // Update selected fields with complete metadata
        this.selectedFields = selectedValues.map(fieldName => {
            const fieldOption = this.fieldOptions.find(option => option.value === fieldName);
            // Create a clone of the field metadata to include all attributes
            const fieldMetadata = {
                name: fieldName,
                type: fieldOption.type,
                required: fieldOption.required,
                label: fieldOption.label
            };
            
            // Include all field attributes from the original field metadata
            if (fieldOption.attributes) {
                Object.keys(fieldOption.attributes).forEach(key => {
                    fieldMetadata[key] = fieldOption.attributes[key];
                });
            }
            
            return fieldMetadata;
        });
        
        // Generate and dispatch configuration change
        this.dispatchConfigChange(this.generateConfigJson());
    }

    /**
     * Handle record count change
     */
    handleRecordCountChange(event) {
        const newValue = parseInt(event.detail.value, 10);
        
        if (newValue > this.MAX_TOTAL_RECORDS) {
            this.recordCount = this.MAX_TOTAL_RECORDS;
            this.showToast(
                'Maximum limit reached',
                `You can create at most ${this.MAX_TOTAL_RECORDS} records`,
                'warning'
            );
        } else if (newValue < 1) {
            this.recordCount = 1;
        } else {
            this.recordCount = newValue;
        }
        
        // Generate and dispatch configuration change
        this.dispatchConfigChange(this.generateConfigJson());
    }

    /**
     * Handle context setting change
     */
    handleContextChange(event) {
        const field = event.target.name;
        const value = event.detail.value;
        
        this.contextSettings = {
            ...this.contextSettings,
            [field]: value
        };
        
        // Generate and dispatch configuration change
        this.dispatchConfigChange(this.generateConfigJson());
    }

    /**
     * Generate configuration JSON
     */
    generateConfigJson() {
        const config = {
            context: this.contextSettings,
            objects: []
        };
        
        if (this.selectedObject) {
            // Create object configuration with metadata
            const objectConfig = {
                name: this.selectedObject,
                count: this.recordCount,
                fields: this.selectedFields.map(field => {
                    // Extract field metadata for LLM processing
                    const fieldMetadata = {
                        name: field.name,
                        type: field.type,
                        label: field.label,
                        required: field.required
                    };
                    
                    // Include all field attributes for validation and data generation
                    if (field.attributes) {
                        // Add important field constraints
                        if (field.type === 'String' && field.attributes.length) {
                            fieldMetadata.length = field.attributes.length;
                        }
                        
                        if (field.type === 'Picklist' && field.attributes.picklistValues) {
                            fieldMetadata.picklistValues = field.attributes.picklistValues;
                        }
                        
                        if (field.type === 'Number' || field.type === 'Currency') {
                            if (field.attributes.precision) fieldMetadata.precision = field.attributes.precision;
                            if (field.attributes.scale) fieldMetadata.scale = field.attributes.scale;
                            if (field.attributes.digits) fieldMetadata.digits = field.attributes.digits;
                        }
                        
                        // Include other important validation attributes
                        if (field.unique) fieldMetadata.unique = true;
                        if (field.externalId) fieldMetadata.externalId = true;
                        
                        // Store all remaining attributes in a metadata object for LLM reference
                        fieldMetadata.metadata = { ...field.attributes };
                    }
                    
                    return fieldMetadata;
                })
            };
            
            config.objects.push(objectConfig);
        }
        
        return JSON.stringify(config, null, 2);
    }

    /**
     * Dispatch configuration change event
     */
    dispatchConfigChange(configJson) {
        const configChangeEvent = new CustomEvent('configchange', {
            detail: { configJson }
        });
        this.dispatchEvent(configChangeEvent);
    }

    /**
     * Show toast notification
     */
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    /**
     * Handle errors
     */
    handleError(error, fallbackMessage) {
        console.error(error);
        let errorMessage = fallbackMessage;
        
        if (error.body && error.body.message) {
            errorMessage = error.body.message;
        } else if (error.message) {
            errorMessage = error.message;
        }
        
        this.showToast('Error', errorMessage, 'error');
    }
} 