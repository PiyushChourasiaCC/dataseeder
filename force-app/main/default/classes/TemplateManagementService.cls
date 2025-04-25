/**
 * TemplateManagementService
 * 
 * Manages DataSeederTemplate__c records, including CRUD operations and import/export.
 */
public with sharing class TemplateManagementService {
    
    /**
     * Get all active templates
     * 
     * @return List<DataSeederTemplate__c> List of active templates
     */
    @AuraEnabled(cacheable=true)
    public static List<DataSeederTemplate__c> getAllActiveTemplates() {
        return [
            SELECT Id, Name, Description__c, ConfigurationJSON__c, IsActive__c,
                   CreatedById, CreatedBy.Name, LastModifiedById, LastModifiedBy.Name
            FROM DataSeederTemplate__c
            WHERE IsActive__c = true
            ORDER BY Name ASC
        ];
    }
    
    /**
     * Get a specific template by ID
     * 
     * @param templateId ID of the template to retrieve
     * @return DataSeederTemplate__c The requested template
     */
    @AuraEnabled
    public static DataSeederTemplate__c getTemplateById(Id templateId) {
        List<DataSeederTemplate__c> templates = [
            SELECT Id, Name, Description__c, ConfigurationJSON__c, IsActive__c,
                   CreatedById, CreatedBy.Name, LastModifiedById, LastModifiedBy.Name
            FROM DataSeederTemplate__c
            WHERE Id = :templateId
        ];
        
        if (templates.isEmpty()) {
            throw new TemplateManagementException('Template not found with ID: ' + templateId);
        }
        
        return templates[0];
    }
    
    /**
     * Create a new template
     * 
     * @param name Template name
     * @param description Template description
     * @param configJson Configuration JSON
     * @param isActive Whether the template is active
     * @return DataSeederTemplate__c The newly created template
     */
    @AuraEnabled
    public static DataSeederTemplate__c createTemplate(String name, String description, String configJson, Boolean isActive) {
        // Validate JSON structure
        validateJsonStructure(configJson);
        
        // Create and insert the template
        DataSeederTemplate__c template = new DataSeederTemplate__c(
            Name = name,
            Description__c = description,
            ConfigurationJSON__c = configJson,
            IsActive__c = isActive
        );
        
        insert template;
        return template;
    }
    
    /**
     * Update an existing template
     * 
     * @param templateId ID of the template to update
     * @param name Updated template name
     * @param description Updated template description
     * @param configJson Updated configuration JSON
     * @param isActive Updated active status
     * @return DataSeederTemplate__c The updated template
     */
    @AuraEnabled
    public static DataSeederTemplate__c updateTemplate(Id templateId, String name, String description, 
                                              String configJson, Boolean isActive) {
        // Validate JSON structure
        validateJsonStructure(configJson);
        
        // Retrieve the template
        DataSeederTemplate__c template = getTemplateById(templateId);
        
        // Update fields
        template.Name = name;
        template.Description__c = description;
        template.ConfigurationJSON__c = configJson;
        template.IsActive__c = isActive;
        
        // Save the template
        update template;
        return template;
    }
    
    /**
     * Delete a template
     * 
     * @param templateId ID of the template to delete
     */
    @AuraEnabled
    public static void deleteTemplate(Id templateId) {
        // Retrieve the template
        DataSeederTemplate__c template = getTemplateById(templateId);
        
        // Delete the template
        delete template;
    }
    
    /**
     * Clone a template
     * 
     * @param sourceTemplateId ID of the template to clone
     * @param newName Name for the cloned template
     * @return DataSeederTemplate__c The cloned template
     */
    @AuraEnabled
    public static DataSeederTemplate__c cloneTemplate(Id sourceTemplateId, String newName) {
        // Retrieve the source template
        DataSeederTemplate__c sourceTemplate = getTemplateById(sourceTemplateId);
        
        // Create the clone
        DataSeederTemplate__c clone = new DataSeederTemplate__c(
            Name = newName,
            Description__c = sourceTemplate.Description__c,
            ConfigurationJSON__c = sourceTemplate.ConfigurationJSON__c,
            IsActive__c = sourceTemplate.IsActive__c
        );
        
        // Insert the clone
        insert clone;
        return clone;
    }
    
    /**
     * Export a template to a document
     * 
     * @param templateId ID of the template to export
     * @return ContentVersion Content document containing the exported template
     */
    public ContentVersion exportTemplate(Id templateId) {
        // Retrieve the template
        DataSeederTemplate__c template = getTemplateById(templateId);
        
        // Create a ContentVersion record
        ContentVersion cv = new ContentVersion();
        cv.Title = template.Name + '.json';
        cv.PathOnClient = template.Name + '.json';
        cv.VersionData = Blob.valueOf(template.ConfigurationJSON__c);
        cv.IsMajorVersion = true;
        
        // Insert the ContentVersion
        insert cv;
        
        // Return the ContentVersion for the caller to use
        return cv;
    }
    
    /**
     * Import a template from a document
     * 
     * @param documentId ID of the ContentVersion document containing the template
     * @param name Name for the imported template
     * @param description Description for the imported template
     * @param isActive Whether the imported template should be active
     * @return DataSeederTemplate__c The imported template
     */
    public DataSeederTemplate__c importTemplate(Id documentId, String name, String description, Boolean isActive) {
        // Retrieve the document
        ContentVersion document = [
            SELECT Id, Title, VersionData
            FROM ContentVersion
            WHERE Id = :documentId
        ];
        
        if (document == null) {
            throw new TemplateManagementException('Document not found with ID: ' + documentId);
        }
        
        // Get the JSON content
        String configJson = document.VersionData.toString();
        
        // Validate JSON structure
        validateJsonStructure(configJson);
        
        // Create the template
        return createTemplate(name, description, configJson, isActive);
    }
    
    /**
     * Validate the structure of a JSON configuration
     * 
     * @param jsonString JSON configuration string to validate
     */
    private static void validateJsonStructure(String jsonString) {
        try {
            // Parse the JSON to verify it's valid
            Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
            
            // Check for required top-level properties
            if (!parsedJson.containsKey('objects')) {
                throw new TemplateManagementException('Invalid JSON structure: missing "objects" property');
            }
            
            // Verify objects is an array
            List<Object> objects = (List<Object>) parsedJson.get('objects');
            if (objects == null) {
                throw new TemplateManagementException('Invalid JSON structure: "objects" property must be an array');
            }
            
            // Check each object
            for (Object obj : objects) {
                Map<String, Object> objectConfig = (Map<String, Object>) obj;
                
                // Check for required properties
                if (!objectConfig.containsKey('name')) {
                    throw new TemplateManagementException('Invalid JSON structure: object missing "name" property');
                }
                
                if (!objectConfig.containsKey('fields')) {
                    throw new TemplateManagementException('Invalid JSON structure: object missing "fields" property');
                }
                
                if (!objectConfig.containsKey('count')) {
                    throw new TemplateManagementException('Invalid JSON structure: object missing "count" property');
                }
                
                // Verify fields is an array
                List<Object> fields = (List<Object>) objectConfig.get('fields');
                if (fields == null) {
                    throw new TemplateManagementException('Invalid JSON structure: "fields" property must be an array');
                }
                
                // Check field count limit
                if (fields.size() > 15) {
                    throw new TemplateManagementException('Invalid JSON structure: object exceeds maximum field limit of 15');
                }
                
                // Check each field
                for (Object fieldObj : fields) {
                    Map<String, Object> field = (Map<String, Object>) fieldObj;
                    
                    // Check for required properties
                    if (!field.containsKey('name')) {
                        throw new TemplateManagementException('Invalid JSON structure: field missing "name" property');
                    }
                    
                    if (!field.containsKey('type')) {
                        throw new TemplateManagementException('Invalid JSON structure: field missing "type" property');
                    }
                }
            }
        } catch (JSONException e) {
            throw new TemplateManagementException('Invalid JSON format: ' + e.getMessage());
        } catch (TemplateManagementException e) {
            throw e;
        } catch (Exception e) {
            throw new TemplateManagementException('Error validating JSON structure: ' + e.getMessage());
        }
    }
    
    /**
     * Get all fields for a specified Salesforce object
     * 
     * @param objectName The API name of the Salesforce object
     * @return List<Map<String, Object>> List of field information
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getObjectFields(String objectName) {
        List<Map<String, Object>> fields = new List<Map<String, Object>>();
        
        try {
            // Get the SObject type
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            if (objectType == null) {
                throw new TemplateManagementException('Object not found: ' + objectName);
            }
            
            // Get the describe result
            Schema.DescribeSObjectResult objDescribe = objectType.getDescribe();
            
            // Check if the user has access to the object
            if (!objDescribe.isAccessible()) {
                throw new TemplateManagementException('You do not have access to object: ' + objectName);
            }
            
            // Get field map
            Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
            
            // Process each field
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                
                // Skip fields the user can't see
                if (!fieldDescribe.isAccessible()) {
                    continue;
                }
                
                // Get field data type
                String fieldType = getFieldType(fieldDescribe);
                
                // Create field info map
                Map<String, Object> fieldInfo = new Map<String, Object>{
                    'name' => fieldName,
                    'label' => fieldDescribe.getLabel(),
                    'type' => fieldType,
                    'required' => !fieldDescribe.isNillable() && !fieldDescribe.isDefaultedOnCreate(),
                    'editable' => fieldDescribe.isUpdateable(),
                    'attributes' => getFieldAttributes(fieldDescribe)
                };
                
                fields.add(fieldInfo);
            }
            
            return fields;
        } catch (Exception e) {
            throw new AuraHandledException('Error getting fields for ' + objectName + ': ' + e.getMessage());
        }
    }
    
    /**
     * Get field type from DescribeFieldResult
     * 
     * @param fieldDescribe The field describe result
     * @return String The field type
     */
    private static String getFieldType(Schema.DescribeFieldResult fieldDescribe) {
        Schema.DisplayType displayType = fieldDescribe.getType();
        
        switch on displayType {
            when STRING, ID, TEXTAREA, URL, PHONE, EMAIL {
                return 'String';
            }
            when INTEGER, LONG, DOUBLE, CURRENCY, PERCENT {
                return 'Number';
            }
            when BOOLEAN {
                return 'Boolean';
            }
            when DATE {
                return 'Date';
            }
            when DATETIME {
                return 'DateTime';
            }
            when PICKLIST, MULTIPICKLIST {
                return 'Picklist';
            }
            when REFERENCE {
                return 'Reference';
            }
            when else {
                return 'String';
            }
        }
    }
    
    /**
     * Get additional field attributes
     * 
     * @param fieldDescribe The field describe result
     * @return Map<String, Object> Map of field attributes
     */
    private static Map<String, Object> getFieldAttributes(Schema.DescribeFieldResult fieldDescribe) {
        Map<String, Object> attributes = new Map<String, Object>();
        
        // Add picklistValues for picklist fields
        if (fieldDescribe.getType() == Schema.DisplayType.PICKLIST || 
            fieldDescribe.getType() == Schema.DisplayType.MULTIPICKLIST) {
            List<Map<String, String>> picklistValues = new List<Map<String, String>>();
            
            for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                if (entry.isActive()) {
                    picklistValues.add(new Map<String, String>{
                        'label' => entry.getLabel(),
                        'value' => entry.getValue()
                    });
                }
            }
            
            attributes.put('picklistValues', picklistValues);
        }
        
        // Add length for text fields
        if (fieldDescribe.getType() == Schema.DisplayType.STRING || 
            fieldDescribe.getType() == Schema.DisplayType.TEXTAREA) {
            attributes.put('length', fieldDescribe.getLength());
        }
        
        // Add reference info for lookup fields
        if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
            List<String> referenceTo = new List<String>();
            for (Schema.SObjectType reference : fieldDescribe.getReferenceTo()) {
                referenceTo.add(reference.getDescribe().getName());
            }
            attributes.put('referenceTo', referenceTo);
        }
        
        return attributes;
    }
    
    /**
     * Custom exception class for template management errors
     */
    public class TemplateManagementException extends Exception {}

    /**
     * Get all objects where the user has create access
     * @return List<Map<String,String>> List of object info with label and API name
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getCreatableObjects() {
        List<Map<String,String>> creatableObjects = new List<Map<String,String>>();
        Map<String, Map<String,String>> objectsByLabel = new Map<String, Map<String,String>>();
        
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        
        for(String objName : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult objDescribe = globalDescribe.get(objName).getDescribe();
            
            // Only include objects that are creatable and not a system object
            if(objDescribe.isCreateable() && 
               !objName.startsWith('System') && 
               !objName.endsWith('__Share') && 
               !objName.endsWith('__History') && 
               !objName.endsWith('__Feed') &&
               !objName.endsWith('ChangeEvent')) {
                
                Map<String,String> objInfo = new Map<String,String>();
                String objLabel = objDescribe.getLabel();
                objInfo.put('label', objLabel);
                objInfo.put('value', objDescribe.getName());
                
                // Store in map by label for sorting
                objectsByLabel.put(objLabel, objInfo);
            }
        }
        
        // Sort by label
        List<String> sortedLabels = new List<String>(objectsByLabel.keySet());
        sortedLabels.sort();
        
        // Build final sorted list
        for(String label : sortedLabels) {
            creatableObjects.add(objectsByLabel.get(label));
        }
        
        return creatableObjects;
    }
    
    /**
     * Determine if a field is a lookup relationship
     * @param fieldDescribe The field describe result
     * @return Boolean True if the field is a lookup
     */
    private static Boolean isLookupField(Schema.DescribeFieldResult fieldDescribe) {
        return (fieldDescribe.getType() == Schema.DisplayType.REFERENCE);
    }
} 