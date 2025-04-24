import { LightningElement, wire, track } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex methods
import getAllActiveTemplates from '@salesforce/apex/TemplateManagementService.getAllActiveTemplates';
import getTemplateById from '@salesforce/apex/TemplateManagementService.getTemplateById';
import createTemplate from '@salesforce/apex/TemplateManagementService.createTemplate';
import updateTemplate from '@salesforce/apex/TemplateManagementService.updateTemplate';
import cloneTemplate from '@salesforce/apex/TemplateManagementService.cloneTemplate';
import deleteTemplate from '@salesforce/apex/TemplateManagementService.deleteTemplate';

export default class SeederConfiguration extends LightningElement {
    @track templates = [];
    @track selectedTemplate = {};
    @track isLoading = false;
    @track showTemplateModal = false;
    @track templateData = {
        id: null,
        name: '',
        description: '',
        configJson: '',
        isActive: true
    };
    @track isEdit = false;
    @track error;
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

    // Constants
    MAX_FIELDS_PER_OBJECT = 15;
    MAX_TOTAL_RECORDS = 50;

    // Getter for selectedTemplateId to safely handle undefined
    get selectedTemplateId() {
        return this.selectedTemplate && this.selectedTemplate.Id ? this.selectedTemplate.Id : '';
    }

    // Computed property for template actions
    get disableTemplateActions() {
        return !this.selectedTemplate || !this.selectedTemplate.Id;
    }

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

    // Computed property to disable JSON editing in modal
    get disableConfigJson() {
        // Only allow direct JSON editing when creating a new template
        return this.isEdit;
    }

    // Field columns for datatable
    fieldColumns = [
        { label: 'Field Name', fieldName: 'name', type: 'text' },
        { label: 'Field Type', fieldName: 'type', type: 'text' }
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
        this.loadTemplates();
    }

    /**
     * Load all active templates
     */
    loadTemplates() {
        this.isLoading = true;
        getAllActiveTemplates()
            .then(result => {
                this.templates = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error, 'Error loading templates');
                this.isLoading = false;
            });
    }

    /**
     * Handle template selection
     */
    handleTemplateChange(event) {
        const templateId = event.detail.value;
        if (templateId) {
            this.isLoading = true;
            getTemplateById({ templateId: templateId })
                .then(result => {
                    this.selectedTemplate = result;
                    try {
                        const config = JSON.parse(result.ConfigurationJSON__c);
                        this.processTemplateConfig(config);
                    } catch (error) {
                        this.handleError(error, 'Error parsing template configuration');
                    }
                    this.isLoading = false;
                })
                .catch(error => {
                    this.handleError(error, 'Error loading template details');
                    this.isLoading = false;
                });
        } else {
            this.selectedTemplate = null;
        }
    }

    /**
     * Process the template configuration
     */
    processTemplateConfig(config) {
        if (config.context) {
            this.contextSettings = { ...config.context };
        }
        
        if (config.objects && config.objects.length > 0) {
            const firstObject = config.objects[0];
            this.selectedObject = firstObject.name;
            this.recordCount = firstObject.count || 5;
            
            if (firstObject.fields) {
                this.selectedFields = firstObject.fields.map(field => ({
                    name: field.name,
                    type: field.type,
                    ...field
                }));
            }
        }
        
        // Dispatch configuration change event with the selected template's JSON
        if (this.selectedTemplate) {
            this.dispatchConfigChange(this.selectedTemplate.ConfigurationJSON__c);
        }
    }

    /**
     * Open the template modal for create/edit
     */
    handleNewTemplate() {
        this.isEdit = false;
        this.templateData = {
            id: null,
            name: '',
            description: '',
            configJson: this.generateConfigJson(),
            isActive: true
        };
        this.showTemplateModal = true;
    }

    /**
     * Open the template modal for editing
     */
    handleEditTemplate() {
        if (!this.selectedTemplate) {
            this.showToast('Error', 'Please select a template to edit', 'error');
            return;
        }
        
        this.isEdit = true;
        this.templateData = {
            id: this.selectedTemplate.Id,
            name: this.selectedTemplate.Name,
            description: this.selectedTemplate.Description__c,
            configJson: this.selectedTemplate.ConfigurationJSON__c,
            isActive: this.selectedTemplate.IsActive__c
        };
        this.showTemplateModal = true;
    }

    /**
     * Handle template modal save
     */
    handleSaveTemplate() {
        this.isLoading = true;
        const { id, name, description, configJson, isActive } = this.templateData;
        
        // Update configuration JSON from current settings
        const updatedConfigJson = this.isEdit ? configJson : this.generateConfigJson();
        
        const savePromise = id ? 
            updateTemplate({ templateId: id, name, description, configJson: updatedConfigJson, isActive }) :
            createTemplate({ name, description, configJson: updatedConfigJson, isActive });
            
        savePromise
            .then(result => {
                this.showToast('Success', `Template ${id ? 'updated' : 'created'} successfully`, 'success');
                this.showTemplateModal = false;
                this.loadTemplates();
                if (!id) {
                    // If creating a new template, select it
                    this.selectedTemplate = result;
                }
            })
            .catch(error => {
                this.handleError(error, `Error ${id ? 'updating' : 'creating'} template`);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Handle template clone
     */
    handleCloneTemplate() {
        if (!this.selectedTemplate) {
            this.showToast('Error', 'Please select a template to clone', 'error');
            return;
        }
        
        const newName = `${this.selectedTemplate.Name} (Clone)`;
        this.isLoading = true;
        
        cloneTemplate({ sourceTemplateId: this.selectedTemplate.Id, newName })
            .then(result => {
                this.showToast('Success', 'Template cloned successfully', 'success');
                this.loadTemplates();
                // Select the new cloned template
                this.selectedTemplate = result;
            })
            .catch(error => {
                this.handleError(error, 'Error cloning template');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Handle template delete
     */
    handleDeleteTemplate() {
        if (!this.selectedTemplate) {
            this.showToast('Error', 'Please select a template to delete', 'error');
            return;
        }
        
        if (!confirm('Are you sure you want to delete this template?')) {
            return;
        }
        
        this.isLoading = true;
        
        deleteTemplate({ templateId: this.selectedTemplate.Id })
            .then(() => {
                this.showToast('Success', 'Template deleted successfully', 'success');
                this.selectedTemplate = null;
                this.loadTemplates();
            })
            .catch(error => {
                this.handleError(error, 'Error deleting template');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Toggle object selector visibility
     */
    handleConfigureObjects() {
        this.showObjectSelector = !this.showObjectSelector;
        if (this.showObjectSelector) {
            // Load available objects
            this.loadObjectOptions();
        }
    }

    /**
     * Toggle field selector visibility
     */
    handleConfigureFields() {
        if (!this.selectedObject) {
            this.showToast('Error', 'Please select an object first', 'error');
            return;
        }
        
        this.showFieldSelector = !this.showFieldSelector;
        if (this.showFieldSelector) {
            // Load available fields for the selected object
            this.loadFieldOptions();
        }
    }

    /**
     * Load available objects
     */
    loadObjectOptions() {
        // In a real implementation, this would call an Apex method to get available objects
        // For now, using a static list of common objects
        this.objectOptions = [
            { label: 'Account', value: 'Account' },
            { label: 'Contact', value: 'Contact' },
            { label: 'Opportunity', value: 'Opportunity' },
            { label: 'Lead', value: 'Lead' },
            { label: 'Case', value: 'Case' }
        ];
    }

    /**
     * Load available fields for selected object
     */
    loadFieldOptions() {
        // In a real implementation, this would call an Apex method to get fields for the selected object
        // For now, using static field options based on the selected object
        if (this.selectedObject === 'Account') {
            this.fieldOptions = [
                { label: 'Name', value: 'Name', type: 'String' },
                { label: 'Phone', value: 'Phone', type: 'Phone' },
                { label: 'Industry', value: 'Industry', type: 'Picklist' },
                { label: 'Type', value: 'Type', type: 'Picklist' },
                { label: 'Website', value: 'Website', type: 'URL' }
            ];
        } else if (this.selectedObject === 'Contact') {
            this.fieldOptions = [
                { label: 'First Name', value: 'FirstName', type: 'String' },
                { label: 'Last Name', value: 'LastName', type: 'String' },
                { label: 'Email', value: 'Email', type: 'Email' },
                { label: 'Phone', value: 'Phone', type: 'Phone' },
                { label: 'Title', value: 'Title', type: 'String' }
            ];
        } else {
            this.fieldOptions = [];
        }
    }

    /**
     * Handle object selection
     */
    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedFields = []; // Reset selected fields when object changes
        if (this.showFieldSelector) {
            this.loadFieldOptions();
        }
        
        // Generate config and dispatch event
        this.generateConfigJson();
    }

    /**
     * Handle field selection
     */
    handleFieldSelection(event) {
        const selectedOptions = event.detail.value;
        
        // Check if adding this field would exceed the limit
        if (selectedOptions.length > this.MAX_FIELDS_PER_OBJECT) {
            this.showToast('Error', `You can only select up to ${this.MAX_FIELDS_PER_OBJECT} fields per object`, 'error');
            return;
        }
        
        // Create field objects based on selection
        this.selectedFields = selectedOptions.map(fieldName => {
            const fieldOption = this.fieldOptions.find(option => option.value === fieldName);
            return {
                name: fieldName,
                type: fieldOption ? fieldOption.type : 'String'
            };
        });
        
        // Generate config and dispatch event
        this.generateConfigJson();
    }

    /**
     * Handle record count change
     */
    handleRecordCountChange(event) {
        const newCount = parseInt(event.detail.value, 10);
        if (isNaN(newCount) || newCount < 1) {
            this.recordCount = 1;
        } else if (newCount > this.MAX_TOTAL_RECORDS) {
            this.recordCount = this.MAX_TOTAL_RECORDS;
            this.showToast('Warning', `Record count limited to maximum of ${this.MAX_TOTAL_RECORDS}`, 'warning');
        } else {
            this.recordCount = newCount;
        }
        
        // Generate config and dispatch event
        this.generateConfigJson();
    }

    /**
     * Handle context setting change
     */
    handleContextChange(event) {
        const field = event.target.name;
        const value = event.target.value;
        this.contextSettings = { ...this.contextSettings, [field]: value };
        
        // Generate config and dispatch event
        this.generateConfigJson();
    }

    /**
     * Generate configuration JSON from current settings
     */
    generateConfigJson() {
        console.log('Context settings before JSON generation:', JSON.stringify(this.contextSettings));
        
        const config = {
            version: '1.0',
            context: { ...this.contextSettings },
            objects: []
        };
        
        if (this.selectedObject && this.selectedFields.length > 0) {
            config.objects.push({
                name: this.selectedObject,
                count: this.recordCount,
                fields: this.selectedFields
            });
        }
        
        console.log('Generated config with context:', JSON.stringify(config.context));
        const configJson = JSON.stringify(config, null, 2);
        
        // Dispatch configuration change event
        this.dispatchConfigChange(configJson);
        
        return configJson;
    }
    
    /**
     * Dispatch configuration change event
     */
    dispatchConfigChange(configJson) {
        this.dispatchEvent(new CustomEvent('configchange', {
            detail: { configJson }
        }));
    }

    /**
     * Handle modal close
     */
    handleModalClose() {
        this.showTemplateModal = false;
    }

    /**
     * Template input change handler
     */
    handleTemplateInputChange(event) {
        const field = event.target.name;
        if (field === 'isActive') {
            this.templateData = { ...this.templateData, [field]: event.target.checked };
        } else {
            this.templateData = { ...this.templateData, [field]: event.target.value };
        }
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
     * Handle error with toast notification
     */
    handleError(error, fallbackMessage) {
        console.error(error);
        const message = error.body?.message || error.message || fallbackMessage;
        this.showToast('Error', message, 'error');
        this.error = message;
    }
} 