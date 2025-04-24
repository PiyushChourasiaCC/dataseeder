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
     * Process the generated data for display
     */
    processGeneratedData(data) {
        if (!data || Object.keys(data).length === 0) {
            this.error = 'No data was generated';
            return;
        }

        // Store data by object type
        for (const [objectName, records] of Object.entries(data)) {
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
        }

        this.successMessage = `Successfully generated sample data for ${this.objectOptions.length} object(s)`;
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
            return;
        }

        // Create columns based on first record
        const firstRecord = records[0];
        const fields = Object.keys(firstRecord).filter(field => 
            field !== 'Id' && field !== 'attributes'
        );

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

        // Convert Map to object for Apex
        const recordsObject = {};
        this.objectMap.forEach((value, key) => {
            recordsObject[key] = value;
        });

        insertRecords({ records: recordsObject })
            .then(result => {
                if (result.success) {
                    let totalRecords = 0;
                    Object.values(result.insertedRecordIds).forEach(ids => {
                        totalRecords += ids.length;
                    });
                    
                    this.successMessage = `Successfully inserted ${totalRecords} records`;
                    this.showToast('Success', this.successMessage, 'success');
                } else {
                    this.error = 'Insert failed: ' + (result.errors ? result.errors.join(', ') : 'Unknown error');
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