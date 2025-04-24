import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex methods
import generateData from '@salesforce/apex/DataGenerationService.generateData';
import insertRecords from '@salesforce/apex/DataInsertionService.insertRecords';
import generateAndInsert from '@salesforce/apex/DataGenerationService.generateAndInsert';

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

    /**
     * Computed property to check if data is empty
     */
    get isDataEmpty() {
        return !this.previewData || this.previewData.length === 0;
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
        this.objectMap.clear();
        this.noValidRecords = false;
        
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

    /**
     * Generate and directly insert records without preview
     */
    generateAndInsertDirectly() {
        if (!this.configJson) {
            this.showToast('Error', 'No configuration provided', 'error');
            return;
        }

        this.isLoading = true;
        this.error = null;
        this.successMessage = null;
        
        // Call Apex method to generate and insert data in one operation
        generateAndInsert({ configJson: this.configJson })
            .then(result => {
                if (result && result.success) {
                    let totalRecords = 0;
                    if (result.insertedRecordCounts) {
                        Object.values(result.insertedRecordCounts).forEach(count => {
                            if (typeof count === 'number') {
                                totalRecords += count;
                            }
                        });
                    }
                    
                    this.successMessage = `Successfully generated and inserted ${totalRecords} records`;
                    this.showToast('Success', this.successMessage, 'success');
                } else {
                    this.error = 'Operation failed: ' + (result && result.errors ? result.errors.join(', ') : 'Unknown error');
                    this.showToast('Error', this.error, 'error');
                }
                this.isLoading = false;
            })
            .catch(error => {
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
                    return;
                }
            }
            
            if (!Array.isArray(data.objects)) {
                this.showToast('Error', 'Invalid data objects format', 'error');
                return;
            }

            // Clear existing data
            this.previewData = [];
            this.objectMap = {};
            let hasValidData = false;

            // Process each object type
            data.objects.forEach(obj => {
                if (!obj.name || !obj.records || !Array.isArray(obj.records)) {
                    console.warn('Skipping invalid object data:', obj);
                    return; // Skip invalid object data
                }

                const objectName = obj.name;
                const recordCount = obj.records.length;
                
                if (recordCount === 0) {
                    console.warn('Skipping object with no records:', objectName);
                    return; // Skip objects with no records
                }

                // Create columns based on the first record's fields
                const columns = [];
                const firstRecord = obj.records[0];
                
                // Debug information to identify issues
                console.log('Processing object:', objectName);
                console.log('First record:', JSON.stringify(firstRecord));

                // Ensure we have a valid record with attributes
                if (!firstRecord || typeof firstRecord !== 'object' || !firstRecord.attributes) {
                    console.error('Invalid record structure for', objectName, firstRecord);
                    return; // Skip this object if record structure is invalid
                }

                // Get all fields from the first record (excluding attributes)
                const fields = Object.keys(firstRecord).filter(key => key !== 'attributes');
                
                // Create a column for each field
                fields.forEach(fieldName => {
                    // Skip internal/system fields
                    if (fieldName.startsWith('_') || fieldName === 'attributes') {
                        return;
                    }
                    
                    const fieldValue = firstRecord[fieldName];
                    const columnType = this.determineColumnType(fieldValue);
                    
                    columns.push({
                        label: this.formatFieldLabel(fieldName),
                        fieldName: fieldName,
                        type: columnType,
                        sortable: true,
                        cellAttributes: { 
                            alignment: columnType === 'number' || columnType === 'currency' ? 'right' : 'left' 
                        }
                    });
                });

                // Format records for datatable
                const formattedRecords = obj.records.map(record => {
                    // Skip invalid records
                    if (!record || typeof record !== 'object' || !record.attributes) {
                        console.warn('Skipping invalid record:', record);
                        return null;
                    }
                    
                    // Create a new record for datatable with a unique id
                    const formattedRecord = { ...record };
                    formattedRecord.id = this.generateId();
                    formattedRecord.sobjectType = record.attributes.type;
                    
                    return formattedRecord;
                }).filter(record => record !== null); // Remove null records

                // Only add objects that have valid records
                if (formattedRecords.length > 0) {
                    hasValidData = true;
                    
                    // Add to object map for selection dropdown
                    this.objectMap[objectName] = {
                        label: this.formatFieldLabel(objectName),
                        value: objectName,
                        count: formattedRecords.length
                    };
                    
                    // Add to preview data
                    this.previewData.push({
                        name: objectName,
                        label: this.formatFieldLabel(objectName),
                        records: formattedRecords,
                        columns: columns,
                        expanded: true
                    });
                }
            });

            // If we have valid data, set the first object as selected
            if (hasValidData) {
                const objectOptions = Object.values(this.objectMap);
                this.objectOptions = objectOptions;
                this.selectedObject = objectOptions[0].value;
            } else {
                this.showToast('Warning', 'No valid records were generated', 'warning');
            }
        } catch (error) {
            console.error('Error processing data:', error);
            this.showToast('Error', 'Error processing generated data: ' + error.message, 'error');
        }
    }

    /**
     * Update displayed data based on selected object
     */
    updateDisplayedData() {
        if (!this.displayedObject || !this.objectMap.has(this.displayedObject)) {
            this.previewData = [];
            this.columns = [];
            this.noValidRecords = true;
            return;
        }

        const records = this.objectMap.get(this.displayedObject);
        
        if (!records || records.length === 0) {
            this.noValidRecords = true;
            return;
        }

        try {
            // Create columns based on first record
            const firstRecord = records[0];
            
            // Get all field names except 'attributes' and 'Id'
            const fields = Object.keys(firstRecord).filter(field => 
                field !== 'Id' && field !== 'attributes'
            );

            if (fields.length === 0) {
                this.noValidRecords = true;
                return;
            }

            this.columns = fields.map(fieldName => ({
                label: this.formatLabel(fieldName),
                fieldName: fieldName,
                type: this.determineColumnType(firstRecord[fieldName])
            }));

            // Create data array for lightning-datatable
            this.previewData = records.map((record, index) => {
                const row = {};
                row.key = index;
                
                // Handle nested or special types for display
                fields.forEach(field => {
                    if (record[field] === null || record[field] === undefined) {
                        row[field] = '';
                    } else if (typeof record[field] === 'object') {
                        // Stringify objects for display
                        row[field] = JSON.stringify(record[field]);
                    } else {
                        row[field] = record[field];
                    }
                });
                
                return row;
            });
            
            // Clear errors if we have data
            if (this.previewData.length > 0) {
                this.noValidRecords = false;
                this.error = null;
            }
        } catch (error) {
            console.error('Error updating displayed data:', error);
            this.noValidRecords = true;
            this.previewData = [];
            this.columns = [];
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
        if (!this.configJson || this.objectMap.size === 0) {
            this.showToast('Error', 'No data available to insert', 'error');
            return;
        }

        this.isLoading = true;
        this.error = null;
        this.successMessage = null;

        try {
            // Convert Map to object for Apex
            const recordsObject = {};
            this.objectMap.forEach((value, key) => {
                // Ensure the values are valid and can be serialized
                if (value && Array.isArray(value) && value.length > 0) {
                    recordsObject[key] = value;
                }
            });

            // Verify we have records to insert
            if (Object.keys(recordsObject).length === 0) {
                throw new Error('No valid records to insert');
            }

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
} 