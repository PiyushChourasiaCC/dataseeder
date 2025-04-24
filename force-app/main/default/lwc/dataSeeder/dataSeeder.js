import { LightningElement, track } from 'lwc';

export default class DataSeeder extends LightningElement {
    @track configJson;
    
    /**
     * Computed property to check if config is empty
     */
    get isConfigEmpty() {
        return !this.configJson;
    }
    
    /**
     * Handle configuration change event from the seederConfiguration component
     */
    handleConfigChange(event) {
        this.configJson = event.detail.configJson;
    }
    
    /**
     * Handle preview button click
     */
    handlePreviewClick() {
        const previewComponent = this.template.querySelector('c-data-preview');
        if (previewComponent) {
            previewComponent.generatePreview();
        }
    }
} 