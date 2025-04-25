import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex methods
import generateData from '@salesforce/apex/DataGenerationService.generateData';
import insertRecords from '@salesforce/apex/DataInsertionService.insertRecords';
import generateAndInsert from '@salesforce/apex/DataGenerationService.generateAndInsert';
import generateDataViaLLM from '@salesforce/apex/DataGenerationService.generateDataViaLLM';

export default class DataPreview extends LightningElement {
    @api configJson;
    @track isLoading = false;
    @track previewData = [];
    @track columns = [];
    @track error;
    @track successMessage;
    @track objectMap = new Map();
    @track displayedObject;
    @track objectOptions = [];
    @track noValidRecords = false;
    @track useNamedCredential = true;

    /**
     * Computed property to check if data is empty
     */
    get isDataEmpty() {
        return !this.previewData || this.previewData.length === 0;
    }
    
    /**
     * Computed property to check if fields are selected
     */
    get hasSelectedFields() {
        if (!this.configJson) return false;
        
        try {
            const config = JSON.parse(this.configJson);
            
            // Check if there are objects with fields defined
            if (config.objects && Array.isArray(config.objects) && config.objects.length > 0) {
                for (const obj of config.objects) {
                    if (obj.fields && Array.isArray(obj.fields) && obj.fields.length > 0) {
                        return true;
                    }
                }
            }
            
            return false;
        } catch (error) {
            console.error('Error parsing configuration:', error);
            return false;
        }
    }

    /**
     * Generate preview data when configuration changes
     */
    @api
    generatePreview() {
        if (!this.configJson) {
            this.showToast('Error', 'No configuration provided', 'error');
            return;
        }

        this.isLoading = true;
        this.error = null;
        this.successMessage = null;
        this.previewData = [];
        this.columns = [];
        this.objectMap = new Map();
        this.noValidRecords = false;
        
        if (this.useNamedCredential) {
            this.generateViaLLM();
        } else {
            generateData({ configJson: this.configJson })
                .then(result => {
                    this.processGeneratedData(result);
                    this.isLoading = false;
                })
                .catch(error => {
                    this.handleError(error, 'Error generating data');
                    this.isLoading = false;
                });
        }
    }

    /**
     * Generate data via the dedicated LLM method
     */
    generateViaLLM() {
        generateDataViaLLM({ configJson: this.configJson })
            .then(result => {
                this.processGeneratedData(result);
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error, 'Error generating data via LLM API');
                this.isLoading = false;
            });
    }

    /**
     * Generate and directly insert records without preview
     */
    generateAndInsertDirectly() {
        if (!this.configJson) {
            this.showToast('Error', 'No configuration provided', 'error');
            return;
        }

        console.log('Starting direct generation and insertion with config:', this.configJson);
        this.isLoading = true;
        this.error = null;
        this.successMessage = null;
        
        // Use the direct generateAndInsert method regardless of LLM setting
        // This ensures consistent behavior and reduces potential errors
        generateAndInsert({ configJson: this.configJson })
            .then(result => {
                console.log('Generation and insertion result:', JSON.stringify(result));
                
                if (result && result.success) {
                    let totalRecords = 0;
                    if (result.insertedRecordCounts) {
                        Object.entries(result.insertedRecordCounts).forEach(([objectType, count]) => {
                            if (typeof count === 'number') {
                                totalRecords += count;
                                console.log(`Inserted ${count} ${objectType} records`);
                            }
                        });
                    }
                    
                    if (totalRecords > 0) {
                        this.successMessage = `Successfully generated and inserted ${totalRecords} records`;
                        this.showToast('Success', this.successMessage, 'success');
                    } else {
                        this.error = 'No records were inserted. Please check your configuration.';
                        this.showToast('Warning', this.error, 'warning');
                    }
                } else {
                    // Handle specific error cases
                    if (result && result.errors && result.errors.length > 0) {
                        this.error = 'Operation failed: ' + result.errors.join(', ');
                    } else {
                        this.error = 'No data was generated to insert. Please check your configuration.';
                    }
                    this.showToast('Error', this.error, 'error');
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error in generateAndInsertDirectly:', error);
                this.handleError(error, 'Error generating and inserting records');
                this.isLoading = false;
            });
    }

    /**
     * Process the generated data for display
     * 
     * @param {Object} data The data returned from Apex
     */
    processGeneratedData(data) {
        try {
            console.log('Received data:', JSON.stringify(data));
            
            // Validate data
            if (!data) {
                this.showToast('Error', 'No data returned from service', 'error');
                this.isLoading = false;
                this.noValidRecords = true;
                return;
            }
            
            // Handle different possible formats
            if (!data.objects) {
                // Try to convert legacy format if needed
                if (typeof data === 'object' && Object.keys(data).length > 0) {
                    const objectsList = [];
                    Object.keys(data).forEach(key => {
                        if (Array.isArray(data[key])) {
                            objectsList.push({
                                name: key,
                                records: data[key]
                            });
                        }
                    });
                    data = { objects: objectsList };
                } else {
                    this.showToast('Error', 'Invalid data format returned', 'error');
                    this.isLoading = false;
                    this.noValidRecords = true;
                    return;
                }
            }
            
            if (!Array.isArray(data.objects) || data.objects.length === 0) {
                this.showToast('Warning', 'No valid records were generated', 'warning');
                this.isLoading = false;
                this.noValidRecords = true;
                return;
            }

            // Clear existing data
            this.previewData = [];
            this.objectMap = {};
            let hasValidData = false;

            // Process each object type
            data.objects.forEach(obj => {
                if (!obj.name || !obj.records || !Array.isArray(obj.records) || obj.records.length === 0) {
                    console.warn('Skipping invalid object data:', obj);
                    return; // Skip invalid object data
                }

                const objectName = obj.name;
                const recordCount = obj.records.length;
                
                console.log(`Processing ${recordCount} ${objectName} records`);

                // Check if all records in this object are valid
                const validRecords = obj.records.filter(record => 
                    record && typeof record === 'object' && 
                    this.isValidSObjectRecord(record, objectName)
                );

                if (validRecords.length === 0) {
                    console.warn(`No valid records found for ${objectName}`);
                    return; // Skip this object if no valid records
                }

                hasValidData = true;
                
                // Use only the first valid record to determine columns
                const firstRecord = validRecords[0];
                const columns = this.buildColumnsFromRecord(firstRecord, objectName);
                
                if (columns.length === 0) {
                    console.warn(`No valid columns found for ${objectName}`);
                    return; // Skip if no columns could be determined
                }
                
                // Create clean record data for display
                const recordData = validRecords.map(record => {
                    // Create a clean data object with only the fields we want to display
                    const cleanRecord = {
                        id: this.generateId(),
                        sobjectType: objectName
                    };
                    
                    // Extract field values
                    columns.forEach(column => {
                        // Only include fields that exist on the record
                        if (record.hasOwnProperty(column.fieldName)) {
                            // Handle special cases like relationship fields
                            if (typeof record[column.fieldName] === 'object' && record[column.fieldName] !== null) {
                                cleanRecord[column.fieldName] = JSON.stringify(record[column.fieldName]);
                            } else {
                                cleanRecord[column.fieldName] = record[column.fieldName];
                            }
                        } else {
                            cleanRecord[column.fieldName] = null;
                        }
                    });
                    
                    return cleanRecord;
                });
                
                // Store in object map
                this.objectMap[objectName] = {
                    records: recordData,
                    columns: columns
                };
            });

            // Check if we have any valid data
            if (!hasValidData) {
                this.noValidRecords = true;
                this.showToast('Warning', 'No valid records could be processed for display', 'warning');
                return;
            }
            
            // Set initial display to first object
            const objectNames = Object.keys(this.objectMap);
            if (objectNames.length > 0) {
                this.objectOptions = objectNames.map(name => ({ label: name, value: name }));
                this.displayedObject = objectNames[0];
                this.updateDisplayedData();
            }
        } catch (error) {
            console.error('Error processing generated data:', error);
            this.showToast('Error', 'Error processing data: ' + error.message, 'error');
            this.isLoading = false;
            this.noValidRecords = true;
        }
    }
    
    /**
     * Check if a record is a valid SObject
     * 
     * @param {Object} record The record to validate
     * @param {String} objectName The name of the SObject type
     * @return {Boolean} True if the record is valid
     */
    isValidSObjectRecord(record, objectName) {
        // Basic structure check
        if (!record || typeof record !== 'object') {
            console.warn('Invalid record: not an object');
            return false;
        }
        
        // Check attributes
        if (!record.attributes) {
            // For some formats, attributes might be missing but the record is still valid
            // We'll create a minimal valid structure
            console.warn('Record missing attributes, attempting to handle');
            record.attributes = { type: objectName };
        }
        
        // Check required fields for common objects
        if (objectName === 'Account' && !record.Name) {
            console.warn('Account record missing Name field');
            return false;
        } else if (objectName === 'Contact' && !record.LastName) {
            console.warn('Contact record missing LastName field');
            return false;
        }
        
        // Check that there's at least one field other than attributes
        const fields = Object.keys(record).filter(key => key !== 'attributes');
        if (fields.length === 0) {
            console.warn('Record has no fields other than attributes');
            return false;
        }
        
        return true;
    }
    
    /**
     * Build column definitions from a record
     * 
     * @param {Object} record The SObject record
     * @param {String} objectName The name of the SObject type
     * @return {Array} Column definitions
     */
    buildColumnsFromRecord(record, objectName) {
        if (!record) return [];
        
        const columns = [];
        
        // Get all fields from the record (excluding attributes)
        const fields = Object.keys(record).filter(key => key !== 'attributes');
        
        // Create a column for each field
        fields.forEach(fieldName => {
            // Skip internal/system fields
            if (fieldName.startsWith('_')) {
                return;
            }
            
            const fieldValue = record[fieldName];
            const columnType = this.determineColumnType(fieldValue);
            
            columns.push({
                label: this.formatFieldLabel(fieldName),
                fieldName: fieldName,
                type: columnType,
                sortable: true,
                editable: false,
                typeAttributes: this.getTypeAttributes(columnType, fieldValue)
            });
        });
        
        return columns;
    }

    /**
     * Update displayed data based on selected object
     */
    updateDisplayedData() {
        console.log('Updating displayed data for object:', this.displayedObject);
        console.log('Object map has keys:', Object.keys(this.objectMap));
        
        if (!this.displayedObject || !this.objectMap[this.displayedObject]) {
            console.warn('No displayed object selected or not found in objectMap');
            this.previewData = [];
            this.columns = [];
            this.noValidRecords = true;
            return;
        }

        const objectData = this.objectMap[this.displayedObject];
        
        if (!objectData || !objectData.records || !objectData.records.length) {
            console.warn('No records for displayed object:', this.displayedObject);
            this.noValidRecords = true;
            return;
        }

        try {
            // Get raw records for this object
            const rawRecords = objectData.records;
            const firstRecord = rawRecords[0];
            
            // Debug information
            console.log('Updating display with first record:', JSON.stringify(firstRecord));
            
            // Get all field names except 'attributes'
            const fields = Object.keys(firstRecord).filter(field => 
                field !== 'attributes'
            );

            if (fields.length === 0) {
                console.warn('No fields found in record');
                this.noValidRecords = true;
                return;
            }

            // Create columns
            this.columns = fields.map(fieldName => ({
                label: this.formatFieldLabel(fieldName),
                fieldName: fieldName,
                type: this.determineColumnType(firstRecord[fieldName])
            }));

            // Format records for datatable
            this.previewData = rawRecords.map((record, index) => {
                const row = {};
                // Use index plus timestamp for unique key
                row.key = `${this.displayedObject}_${index}_${Date.now()}`;
                
                // Copy fields but exclude attributes
                Object.keys(record).forEach(field => {
                    if (field !== 'attributes') {
                        // Handle special types for display
                        if (record[field] === null || record[field] === undefined) {
                            row[field] = '';
                        } else if (typeof record[field] === 'object') {
                            // Stringify objects for display
                            row[field] = JSON.stringify(record[field]);
                        } else {
                            row[field] = record[field];
                        }
                    }
                });
                
                return row;
            });
            
            // Clear errors if we have data
            if (this.previewData.length > 0) {
                console.log('Successfully updated display with', this.previewData.length, 'records');
                this.noValidRecords = false;
                this.error = null;
            } else {
                console.warn('No valid records found after processing');
                this.noValidRecords = true;
            }
        } catch (error) {
            console.error('Error updating displayed data:', error);
            this.noValidRecords = true;
            this.previewData = [];
            this.columns = [];
            this.error = error.message || 'Error displaying records';
        }
    }

    /**
     * Format a field name as a nicer label
     */
    formatLabel(fieldName) {
        // Special case for fields ending with __c (custom fields)
        if (fieldName.endsWith('__c')) {
            fieldName = fieldName.substring(0, fieldName.length - 3);
        }
        
        // Split by capital letters and underscores
        const words = fieldName.split(/(?=[A-Z])/).join(' ').split('_').join(' ');
        
        // Capitalize first letter of each word
        return words.split(' ')
            .map(word => word.charAt(0).toUpperCase() + word.slice(1))
            .join(' ');
    }

    /**
     * Handle insert button click
     */
    handleInsert() {
        if (!this.configJson || Object.keys(this.objectMap).length === 0) {
            this.showToast('Error', 'No data available to insert', 'error');
            return;
        }

        this.isLoading = true;
        this.error = null;
        this.successMessage = null;

        try {
            // Create records map for Apex
            const recordsObject = {};
            
            // Add records for each object type
            Object.keys(this.objectMap).forEach(objectName => {
                const objectData = this.objectMap[objectName];
                
                // Ensure we have valid records
                if (objectData && objectData.records && objectData.records.length > 0) {
                    recordsObject[objectName] = objectData.records;
                }
            });

            // Verify we have records to insert
            if (Object.keys(recordsObject).length === 0) {
                throw new Error('No valid records to insert');
            }
            
            console.log('Sending records for insertion:', JSON.stringify(recordsObject));

            insertRecords({ records: recordsObject })
                .then(result => {
                    if (result && result.success) {
                        let totalRecords = 0;
                        if (result.insertedRecordIds) {
                            Object.values(result.insertedRecordIds).forEach(ids => {
                                if (ids && Array.isArray(ids)) {
                                    totalRecords += ids.length;
                                }
                            });
                        }
                        
                        this.successMessage = `Successfully inserted ${totalRecords} records`;
                        this.showToast('Success', this.successMessage, 'success');
                    } else {
                        this.error = 'Insert failed: ' + (result && result.errors ? result.errors.join(', ') : 'Unknown error');
                        this.showToast('Error', this.error, 'error');
                    }
                    this.isLoading = false;
                })
                .catch(error => {
                    this.handleError(error, 'Error inserting records');
                    this.isLoading = false;
                });
        } catch (error) {
            this.handleError(error, 'Error preparing records for insertion');
            this.isLoading = false;
        }
    }

    /**
     * Handle object selection change
     */
    handleObjectChange(event) {
        this.displayedObject = event.detail.value;
        this.updateDisplayedData();
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

    /**
     * Generate a unique ID for records
     * @returns {string} A unique ID
     */
    generateId() {
        return 'id_' + Math.random().toString(36).substr(2, 9);
    }

    /**
     * Format a field name into a readable label
     * @param {string} fieldName The API name of the field
     * @returns {string} A formatted label
     */
    formatFieldLabel(fieldName) {
        if (!fieldName) return '';
        // Handle relationship fields
        if (fieldName.endsWith('__r')) {
            fieldName = fieldName.replace('__r', '');
        }
        // Split by underscore and capitalize
        return fieldName
            .replace(/__c$/g, '')
            .replace(/_/g, ' ')
            .split(/(?=[A-Z])/).join(' ')
            .replace(/\b\w/g, l => l.toUpperCase());
    }

    /**
     * Determine the column type based on the field value
     * @param {*} value The field value
     * @returns {string} The column type for lightning-datatable
     */
    determineColumnType(value) {
        if (value === null || value === undefined) {
            return 'text';
        }
        
        const type = typeof value;
        
        switch (type) {
            case 'number':
                return Number.isInteger(value) ? 'number' : 'currency';
            case 'boolean':
                return 'boolean';
            case 'object':
                if (value instanceof Date) {
                    return 'date';
                }
                return 'text';
            default:
                // Check if it looks like a date string
                if (typeof value === 'string' && 
                    (value.match(/^\d{4}-\d{2}-\d{2}$/) || 
                     value.match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/))) {
                    return 'date';
                }
                return 'text';
        }
    }

    /**
     * Get type attributes based on column type and field value
     * @param {string} columnType The column type
     * @param {*} fieldValue The field value
     * @returns {Object} Type attributes for lightning-datatable
     */
    getTypeAttributes(columnType, fieldValue) {
        const attributes = {};
        
        if (columnType === 'date') {
            attributes.day = '2-digit';
            attributes.month = '2-digit';
            attributes.year = 'numeric';
        } else if (columnType === 'currency') {
            attributes.style = 'currency';
            attributes.currency = 'USD';
        }
        
        return attributes;
    }
} 