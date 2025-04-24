/**
 * Test class for TemplateManagementService
 * 
 * Provides test coverage for template management functionality.
 */
@isTest
public class TemplateManagementServiceTest {
    
    /**
     * Test creating, retrieving, and listing templates
     */
    @isTest
    static void testCreateAndRetrieveTemplate() {
        // Test data
        String name = 'Test Template';
        String description = 'Test Description';
        String configJson = getValidJsonConfig();
        Boolean isActive = true;
        
        // Execute test - create template
        Test.startTest();
        DataSeederTemplate__c createdTemplate = TemplateManagementService.createTemplate(name, description, configJson, isActive);
        Test.stopTest();
        
        // Verify template was created
        System.assertNotEquals(null, createdTemplate.Id, 'Template should be created with an ID');
        System.assertEquals(name, createdTemplate.Name, 'Template name should match');
        System.assertEquals(description, createdTemplate.Description__c, 'Template description should match');
        System.assertEquals(configJson, createdTemplate.ConfigurationJSON__c, 'Template JSON should match');
        System.assertEquals(isActive, createdTemplate.IsActive__c, 'Template active status should match');
        
        // Verify retrieving by ID
        DataSeederTemplate__c retrievedTemplate = TemplateManagementService.getTemplateById(createdTemplate.Id);
        System.assertEquals(createdTemplate.Id, retrievedTemplate.Id, 'Retrieved template should match created template');
        
        // Verify retrieving all active templates
        List<DataSeederTemplate__c> activeTemplates = TemplateManagementService.getAllActiveTemplates();
        System.assertEquals(1, activeTemplates.size(), 'Should have one active template');
        System.assertEquals(createdTemplate.Id, activeTemplates[0].Id, 'Active template should match created template');
    }
    
    /**
     * Test updating a template
     */
    @isTest
    static void testUpdateTemplate() {
        // Create initial template
        DataSeederTemplate__c template = createTestTemplate();
        
        // Execute test - update template
        Test.startTest();
        String updatedName = 'Updated Template';
        String updatedDescription = 'Updated Description';
        String updatedJson = getValidJsonConfig();
        Boolean updatedStatus = false;
        
        DataSeederTemplate__c updatedTemplate = TemplateManagementService.updateTemplate(
            template.Id, updatedName, updatedDescription, updatedJson, updatedStatus
        );
        Test.stopTest();
        
        // Verify template was updated
        System.assertEquals(template.Id, updatedTemplate.Id, 'Template ID should remain the same');
        System.assertEquals(updatedName, updatedTemplate.Name, 'Template name should be updated');
        System.assertEquals(updatedDescription, updatedTemplate.Description__c, 'Template description should be updated');
        System.assertEquals(updatedJson, updatedTemplate.ConfigurationJSON__c, 'Template JSON should be updated');
        System.assertEquals(updatedStatus, updatedTemplate.IsActive__c, 'Template active status should be updated');
        
        // Verify changes are persisted
        DataSeederTemplate__c retrievedTemplate = TemplateManagementService.getTemplateById(template.Id);
        System.assertEquals(updatedName, retrievedTemplate.Name, 'Updates should be persisted');
    }
    
    /**
     * Test deleting a template
     */
    @isTest
    static void testDeleteTemplate() {
        // Create initial template
        DataSeederTemplate__c template = createTestTemplate();
        
        // Execute test - delete template
        Test.startTest();
        TemplateManagementService.deleteTemplate(template.Id);
        Test.stopTest();
        
        // Verify template was deleted
        List<DataSeederTemplate__c> templates = [SELECT Id FROM DataSeederTemplate__c WHERE Id = :template.Id];
        System.assertEquals(0, templates.size(), 'Template should be deleted');
        
        // Verify exception when attempting to retrieve deleted template
        Boolean exceptionThrown = false;
        try {
            TemplateManagementService.getTemplateById(template.Id);
        } catch (TemplateManagementService.TemplateManagementException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Template not found'), 'Exception should indicate template not found');
        }
        System.assert(exceptionThrown, 'Exception should be thrown when retrieving deleted template');
    }
    
    /**
     * Test cloning a template
     */
    @isTest
    static void testCloneTemplate() {
        // Create initial template
        DataSeederTemplate__c template = createTestTemplate();
        
        // Execute test - clone template
        Test.startTest();
        String cloneName = 'Cloned Template';
        DataSeederTemplate__c clonedTemplate = TemplateManagementService.cloneTemplate(template.Id, cloneName);
        Test.stopTest();
        
        // Verify clone was created correctly
        System.assertNotEquals(template.Id, clonedTemplate.Id, 'Clone should have a different ID');
        System.assertEquals(cloneName, clonedTemplate.Name, 'Clone should have the specified name');
        System.assertEquals(template.Description__c, clonedTemplate.Description__c, 'Clone should have the same description');
        System.assertEquals(template.ConfigurationJSON__c, clonedTemplate.ConfigurationJSON__c, 'Clone should have the same JSON');
        System.assertEquals(template.IsActive__c, clonedTemplate.IsActive__c, 'Clone should have the same active status');
    }
    
    /**
     * Test validation of JSON structure
     */
    @isTest
    static void testJsonValidation() {
        // Test case 1: Invalid JSON format
        Test.startTest();
        String invalidJson = '{this is not valid json}';
        Boolean exceptionThrown = false;
        
        try {
            TemplateManagementService.createTemplate('Test', 'Test', invalidJson, true);
        } catch (TemplateManagementService.TemplateManagementException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Invalid JSON format'), 'Exception should indicate invalid JSON format');
        }
        System.assert(exceptionThrown, 'Exception should be thrown for invalid JSON format');
        
        // Test case 2: Missing required properties
        exceptionThrown = false;
        String missingPropsJson = '{"some_property": "value"}';
        
        try {
            TemplateManagementService.createTemplate('Test', 'Test', missingPropsJson, true);
        } catch (TemplateManagementService.TemplateManagementException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('missing "objects" property'), 'Exception should indicate missing objects property');
        }
        System.assert(exceptionThrown, 'Exception should be thrown for missing properties');
        
        // Test case 3: Too many fields
        exceptionThrown = false;
        String tooManyFieldsJson = '{"objects": [{"name": "Account", "count": 1, "fields": [';
        for (Integer i = 0; i < 20; i++) {
            tooManyFieldsJson += '{"name": "Field' + i + '", "type": "String"}';
            if (i < 19) tooManyFieldsJson += ',';
        }
        tooManyFieldsJson += ']}]}';
        
        try {
            TemplateManagementService.createTemplate('Test', 'Test', tooManyFieldsJson, true);
        } catch (TemplateManagementService.TemplateManagementException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('exceeds maximum field limit'), 'Exception should indicate too many fields');
        }
        System.assert(exceptionThrown, 'Exception should be thrown for too many fields');
        Test.stopTest();
    }
    
    /**
     * Test exporting a template to a content document
     */
    @isTest
    static void testExportTemplate() {
        // Create initial template
        DataSeederTemplate__c template = createTestTemplate();
        
        // Create service
        TemplateManagementService service = new TemplateManagementService();
        
        // Execute test - export template
        Test.startTest();
        ContentVersion cv = service.exportTemplate(template.Id);
        Test.stopTest();
        
        // Verify ContentVersion was created
        System.assertNotEquals(null, cv.Id, 'ContentVersion should be created');
        System.assertEquals(template.Name + '.json', cv.Title, 'ContentVersion title should match template name');
        System.assertEquals(template.ConfigurationJSON__c, cv.VersionData.toString(), 'ContentVersion data should match template JSON');
    }
    
    /**
     * Test importing a template from a content document
     */
    @isTest
    static void testImportTemplate() {
        // Create a ContentVersion with JSON data
        String configJson = getValidJsonConfig();
        ContentVersion cv = new ContentVersion();
        cv.Title = 'import-test.json';
        cv.PathOnClient = 'import-test.json';
        cv.VersionData = Blob.valueOf(configJson);
        cv.IsMajorVersion = true;
        insert cv;
        
        // Create service
        TemplateManagementService service = new TemplateManagementService();
        
        // Execute test - import template
        Test.startTest();
        String importName = 'Imported Template';
        String importDesc = 'Imported Description';
        Boolean importActive = true;
        
        DataSeederTemplate__c importedTemplate = service.importTemplate(cv.Id, importName, importDesc, importActive);
        Test.stopTest();
        
        // Verify template was imported
        System.assertNotEquals(null, importedTemplate.Id, 'Imported template should have an ID');
        System.assertEquals(importName, importedTemplate.Name, 'Imported template name should match');
        System.assertEquals(importDesc, importedTemplate.Description__c, 'Imported template description should match');
        System.assertEquals(configJson, importedTemplate.ConfigurationJSON__c, 'Imported template JSON should match ContentVersion data');
        System.assertEquals(importActive, importedTemplate.IsActive__c, 'Imported template active status should match');
    }
    
    /**
     * Helper method to create a test template
     */
    private static DataSeederTemplate__c createTestTemplate() {
        String name = 'Test Template';
        String description = 'Test Description';
        String configJson = getValidJsonConfig();
        Boolean isActive = true;
        
        DataSeederTemplate__c template = TemplateManagementService.createTemplate(name, description, configJson, isActive);
        return template;
    }
    
    /**
     * Helper method to get a valid JSON configuration for testing
     */
    private static String getValidJsonConfig() {
        return '{"objects": [{"name": "Account", "count": 2, "fields": [{"name": "Name", "type": "String"}]}]}';
    }
} 