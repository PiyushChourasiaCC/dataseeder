import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex methods
import generateData from '@salesforce/apex/DataGenerationService.generateData';
import insertRecords from '@salesforce/apex/DataInsertionService.insertRecords';

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
     * Process data returned from the Apex method
     */
    processGeneratedData(result) {
        try {
            this.isLoading = false;
            this.error = null;
            
            // Clear any previous data
            this.objectMap = new Map();
            
            if (!result || Object.keys(result).length === 0) {
                this.error = 'No data was returned from the server. Please check your configuration.';
                console.error('Data generation returned empty result:', result);
                return;
            }
            
            // Process each object's records
            for (const [objectName, records] of Object.entries(result)) {
                if (records && records.length > 0) {
                    this.objectMap.set(objectName, records);
                }
            }
            
            // Create options for object selection
            this.objectOptions = Array.from(this.objectMap.keys()).map(key => ({
                label: key,
                value: key
            }));
            
            // Default to first object
            if (this.objectOptions.length > 0) {
                this.displayedObject = this.objectOptions[0].value;
                this.updateDisplayedData();
            } else {
                this.error = 'No valid SObject records were generated. Check that required fields have valid values.';
                console.error('No valid SObjects in result:', result);
            }
        } catch (error) {
            this.handleError(error);
        }
    }

    /**
     * Update displayed data based on selected object
     */
    updateDisplayedData() {
        if (!this.displayedObject || !this.objectMap.has(this.displayedObject)) {
            this.previewData = [];
            this.columns = [];
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
            
            // Check if we have a valid SObject record
            if (!firstRecord || !firstRecord.attributes) {
                this.noValidRecords = true;
                return;
            }
            
            const fields = Object.keys(firstRecord).filter(field => 
                field !== 'Id' && field !== 'attributes'
            );

            if (fields.length === 0) {
                this.noValidRecords = true;
                return;
            }

            this.columns = fields.map(fieldName => ({
                label: fieldName,
                fieldName: fieldName,
                type: this.determineColumnType(firstRecord[fieldName])
            }));

            // Create data array for lightning-datatable
            this.previewData = records.map((record, index) => {
                const row = { ...record, key: index };
                
                // Handle nested or special types for display
                fields.forEach(field => {
                    if (record[field] === null || record[field] === undefined) {
                        row[field] = '';
                    } else if (typeof record[field] === 'object') {
                        // Stringify objects for display
                        row[field] = JSON.stringify(record[field]);
                    }
                });
                
                return row;
            });
            
            this.noValidRecords = false;
        } catch (error) {
            console.error('Error updating displayed data:', error);
            this.noValidRecords = true;
            this.previewData = [];
            this.columns = [];
        }
    }

    /**
     * Determine the column type based on field value
     */
    determineColumnType(value) {
        if (value === null || value === undefined) {
            return 'text';
        }

        const type = typeof value;
        switch (type) {
            case 'number':
                return 'number';
            case 'boolean':
                return 'boolean';
            case 'object':
                if (value instanceof Date) {
                    return 'date';
                }
                return 'text';
            default:
                return 'text';
        }
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
} 