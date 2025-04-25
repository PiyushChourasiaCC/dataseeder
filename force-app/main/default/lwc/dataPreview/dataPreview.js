import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex methods
import generateData from '@salesforce/apex/DataGenerationService.generateData';
import insertRecordsFromJson from '@salesforce/apex/DataInsertionService.insertRecordsFromJson';
import generateAndInsert from '@salesforce/apex/DataGenerationService.generateAndInsert';

export default class DataPreview extends LightningElement {
    @api configJson;
    @track isLoading = false;
    @track previewData = [];
    @track columns = [];
    @track error;
    @track successMessage;
    @track objectMap = {};
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
        this.objectMap = {};
        this.noValidRecords = false;
        
        // Use the same method that's called by the Generate & Insert Directly button
        // but we'll only get the data without inserting
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
                this.isLoading = false;
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
                    return;
                }
            }
            
            if (!Array.isArray(data.objects)) {
                this.showToast('Error', 'Invalid data objects format', 'error');
                this.isLoading = false;
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

                // Process records to ensure they have proper attributes
                const processedRecords = this.ensureRecordAttributes(obj.records, objectName);
                if (processedRecords.length === 0) {
                    console.warn('No valid records found after processing for', objectName);
                    return;
                }

                // Create columns dynamically based on the first record
                const columns = this.createColumnsFromRecord(processedRecords[0], objectName);
                if (columns.length === 0) {
                    console.warn('No valid columns found for', objectName);
                    return;
                }

                // Format records for the datatable
                const formattedRecords = this.formatRecordsForDataTable(processedRecords);
                if (formattedRecords.length === 0) {
                    console.warn('No valid formatted records for', objectName);
                    return;
                }

                // We have valid records and columns
                hasValidData = true;
                
                // Store in object map for selection dropdown
                this.objectMap[objectName] = {
                    label: this.formatFieldLabel(objectName),
                    value: objectName,
                    count: formattedRecords.length,
                    records: processedRecords,
                    columns: columns,
                    formattedRecords: formattedRecords
                };
                
                // Set the first object as displayed by default
                if (!this.displayedObject) {
                    this.displayedObject = objectName;
                    this.columns = columns;
                    this.previewData = formattedRecords;
                }
            });

            // Create object options for the dropdown
            if (hasValidData) {
                const objectOptions = [];
                
                Object.keys(this.objectMap).forEach(key => {
                    objectOptions.push({
                        label: `${this.objectMap[key].label} (${this.objectMap[key].count})`,
                        value: key
                    });
                });
                
                this.objectOptions = objectOptions;
                
                if (!this.displayedObject && objectOptions.length > 0) {
                    this.displayedObject = objectOptions[0].value;
                    this.updateDisplayedData();
                }
            } else {
                this.showToast('Warning', 'No valid records were generated', 'warning');
                this.noValidRecords = true;
            }
            
            this.isLoading = false;
        } catch (error) {
            console.error('Error processing data:', error);
            this.showToast('Error', 'Error processing generated data: ' + error.message, 'error');
            this.isLoading = false;
            this.noValidRecords = true;
        }
    }

    /**
     * Ensure all records have proper attributes for serialization
     */
    ensureRecordAttributes(records, objectName) {
        const processedRecords = [];
        
        if (!records || !Array.isArray(records) || !objectName) {
            return processedRecords;
        }
        
        records.forEach(record => {
            try {
                if (!record) return;
                
                // Create a copy to avoid modifying the original
                const recordCopy = { ...record };
                
                // Ensure the record has attributes
                if (!recordCopy.attributes) {
                    recordCopy.attributes = { type: objectName };
                } else if (typeof recordCopy.attributes === 'object') {
                    // Ensure the type attribute is set correctly
                    if (!recordCopy.attributes.type) {
                        recordCopy.attributes.type = objectName;
                    }
                }
                
                // Ensure all field values are properly typed for display
                Object.keys(recordCopy).forEach(field => {
                    if (field !== 'attributes') {
                        if (recordCopy[field] === null || recordCopy[field] === undefined) {
                            recordCopy[field] = '';
                        }
                    }
                });
                
                processedRecords.push(recordCopy);
            } catch (error) {
                console.error('Error processing record:', error);
            }
        });
        
        return processedRecords;
    }

    /**
     * Create columns from a record
     */
    createColumnsFromRecord(record, objectName) {
        const columns = [];
        
        if (!record || typeof record !== 'object') {
            return columns;
        }
        
        // Get all fields excluding attributes
        const fields = Object.keys(record).filter(key => key !== 'attributes');
        
        // Create a column for each field
        fields.forEach(fieldName => {
            // Skip system fields
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
                cellAttributes: { 
                    alignment: columnType === 'number' || columnType === 'currency' ? 'right' : 'left' 
                }
            });
        });
        
        return columns;
    }

    /**
     * Format records for the lightning datatable
     */
    formatRecordsForDataTable(records) {
        const formattedRecords = [];
        
        if (!records || !Array.isArray(records)) {
            return formattedRecords;
        }
        
        records.forEach((record, index) => {
            try {
                const row = {};
                
                // Add a unique key for the datatable
                row.key = `row_${index}_${Date.now()}`;
                
                // Copy all fields except attributes
                Object.keys(record).forEach(field => {
                    if (field !== 'attributes') {
                        // Format values for display
                        if (record[field] === null || record[field] === undefined) {
                            row[field] = '';
                        } else if (typeof record[field] === 'object') {
                            // Handle objects by converting to string
                            row[field] = JSON.stringify(record[field]);
                        } else {
                            row[field] = record[field];
                        }
                    }
                });
                
                formattedRecords.push(row);
            } catch (error) {
                console.error('Error formatting record:', error);
            }
        });
        
        return formattedRecords;
    }

    /**
     * Update displayed data based on selected object
     */
    updateDisplayedData() {
        console.log('Updating displayed data for object:', this.displayedObject);
        
        if (!this.displayedObject || !this.objectMap[this.displayedObject]) {
            console.warn('No displayed object selected or not found in objectMap');
            this.previewData = [];
            this.columns = [];
            this.noValidRecords = true;
            return;
        }

        const objectData = this.objectMap[this.displayedObject];
        
        if (!objectData || !objectData.formattedRecords || !objectData.formattedRecords.length) {
            console.warn('No records for displayed object:', this.displayedObject);
            this.noValidRecords = true;
            return;
        }

        try {
            // Use the pre-processed columns and records
            this.columns = objectData.columns;
            this.previewData = objectData.formattedRecords;
            
            // Clear error if we have data
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
     * Handle object change from dropdown
     */
    handleObjectChange(event) {
        this.displayedObject = event.detail.value;
        this.updateDisplayedData();
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

        // Create records map from object map for insertion
        const recordsMap = {};
        Object.keys(this.objectMap).forEach(objectName => {
            recordsMap[objectName] = this.objectMap[objectName].records;
        });

        // Call Apex to insert the records
        insertRecordsFromJson({ recordsJson: JSON.stringify(recordsMap) })
            .then(result => {
                if (result && result.success) {
                    let totalRecords = 0;
                    const recordCounts = result.insertedRecordIds || {};
                    
                    Object.keys(recordCounts).forEach(objName => {
                        const count = recordCounts[objName].length;
                        totalRecords += count;
                    });
                    
                    this.successMessage = `Successfully inserted ${totalRecords} records`;
                    this.showToast('Success', this.successMessage, 'success');
                } else {
                    this.error = 'Insert operation failed: ' + (result && result.errors ? result.errors.join(', ') : 'Unknown error');
                    this.showToast('Error', this.error, 'error');
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error, 'Error inserting records');
                this.isLoading = false;
            });
    }

    /**
     * Show a toast message
     */
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant || 'info'
            })
        );
    }

    /**
     * Handle errors from Apex calls
     */
    handleError(error, fallbackMessage) {
        console.error(fallbackMessage, error);
        const errorMsg = error.body?.message || error.message || fallbackMessage;
        this.error = errorMsg;
        this.showToast('Error', errorMsg, 'error');
    }

    /**
     * Generate a unique ID for records
     */
    generateId() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    }

    /**
     * Format a field name for display
     */
    formatFieldLabel(fieldName) {
        // Special case for custom fields ending with __c
        if (fieldName.endsWith('__c')) {
            fieldName = fieldName.substring(0, fieldName.length - 3);
        }
        
        // Split by capital letters and underscores
        return fieldName
            .replace(/_/g, ' ')
            .replace(/([A-Z])/g, ' $1')
            .replace(/^./, str => str.toUpperCase())
            .trim();
    }

    /**
     * Determine the column type based on value
     */
    determineColumnType(value) {
        if (value === null || value === undefined) {
            return 'text';
        }
        
        const type = typeof value;
        
        if (type === 'number') {
            return value % 1 === 0 ? 'number' : 'currency';
        } else if (type === 'boolean') {
            return 'boolean';
        } else if (type === 'string') {
            // Check if it's a URL
            if (value.startsWith('http://') || value.startsWith('https://')) {
                return 'url';
            }
            
            // Check if it's an email
            if (value.includes('@') && value.includes('.')) {
                return 'email';
            }
            
            // Check if it's a phone number
            if (/^\+?[\d\s-().]+$/.test(value)) {
                return 'phone';
            }
            
            // Check if it's a date
            if (/^\d{4}-\d{2}-\d{2}/.test(value)) {
                return 'date';
            }
        }
        
        return 'text';
    }
} 