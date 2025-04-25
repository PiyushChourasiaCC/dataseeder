/**
 * Test class for DataGenerationService
 * 
 * Covers validation and data generation functionality
 */
@isTest
private class DataGenerationServiceTest {
    
    /**
     * Test that valid JSON configuration is parsed correctly
     */
    @isTest
    static void testParseValidConfiguration() {
        // Create test data
        String configJson = getValidConfigJson();
        
        // Execute test
        Test.startTest();
        Map<String, Object> result = DataGenerationService.generateData(configJson);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, result, 'Result should not be null');
        
        // Get the objects list from the result
        List<Map<String, Object>> objectsList = (List<Map<String, Object>>)result.get('objects');
        System.assertNotEquals(null, objectsList, 'Objects list should not be null');
        System.assertEquals(1, objectsList.size(), 'Should create data for one object');
        
        // Find the Account object data
        Map<String, Object> accountData = null;
        for(Map<String, Object> objData : objectsList) {
            if('Account'.equals(objData.get('name'))) {
                accountData = objData;
                break;
            }
        }
        
        System.assertNotEquals(null, accountData, 'Should contain Account data');
        List<SObject> accounts = (List<SObject>)accountData.get('records');
        System.assertEquals(2, accounts.size(), 'Should create 2 Account records');
    }
    
    /**
     * Test invalid JSON format
     */
    @isTest
    static void testInvalidJsonFormat() {
        // Create invalid JSON
        String invalidJson = '{this is not valid json}';
        
        // Execute test
        Test.startTest();
        Boolean exceptionCaught = false;
        try {
            DataGenerationService.generateData(invalidJson);
        } catch (AuraHandledException e) {
            // Expected exception
            exceptionCaught = true;
        }
        System.assert(exceptionCaught, 'Should throw an exception for invalid JSON');
        Test.stopTest();
    }
    
    /**
     * Test missing required fields in configuration
     */
    @isTest
    static void testMissingRequiredFields() {
        // Create JSON missing required fields
        String missingFieldsJson = '{"objects": [{"name": "Account"}]}';
        
        // Execute test
        Test.startTest();
        Boolean exceptionCaught = false;
        try {
            DataGenerationService.generateData(missingFieldsJson);
        } catch (AuraHandledException e) {
            // Expected exception
            exceptionCaught = true;
        }
        System.assert(exceptionCaught, 'Should throw an exception for missing required fields');
        Test.stopTest();
    }
    
    /**
     * Test exceeding maximum field limit
     */
    @isTest
    static void testExceedingFieldLimit() {
        // Create JSON with too many fields
        String tooManyFieldsJson = '{"objects": [{"name": "Account", "count": 1, "fields": [';
        for (Integer i = 0; i < 20; i++) {
            tooManyFieldsJson += '{"name": "Field' + i + '", "type": "String"}';
            if (i < 19) tooManyFieldsJson += ',';
        }
        tooManyFieldsJson += ']}]}';
        
        // Execute test
        Test.startTest();
        Boolean exceptionCaught = false;
        try {
            DataGenerationService.generateData(tooManyFieldsJson);
        } catch (AuraHandledException e) {
            // Expected exception
            exceptionCaught = true;
        }
        System.assert(exceptionCaught, 'Should throw an exception for exceeding field limit');
        Test.stopTest();
    }
    
    /**
     * Test exceeding total record limit
     */
    @isTest
    static void testExceedingTotalRecordLimit() {
        // Create JSON with too many records
        String tooManyRecordsJson = '{"objects": [{"name": "Account", "count": 51, "fields": [{"name": "Name", "type": "String"}]}]}';
        
        // Execute test
        Test.startTest();
        Boolean exceptionCaught = false;
        try {
            DataGenerationService.generateData(tooManyRecordsJson);
        } catch (AuraHandledException e) {
            // Expected exception
            exceptionCaught = true;
        }
        System.assert(exceptionCaught, 'Should throw an exception for exceeding record limit');
        Test.stopTest();
    }
    
    /**
     * Test field value generation
     */
    @isTest
    static void testFieldValueGeneration() {
        // Create JSON with various field types
        String configJson = '{"objects": [{"name": "Account", "count": 1, "fields": [' +
            '{"name": "Name", "type": "String", "length": 50},' +
            '{"name": "NumberOfEmployees", "type": "Number", "minValue": 10, "maxValue": 100},' +
            '{"name": "Website", "type": "String"},' +
            '{"name": "Industry", "type": "Picklist", "picklistValues": ["Technology", "Healthcare", "Retail"]}' +
            ']}]}';
        
        // Execute test
        Test.startTest();
        Map<String, Object> result = DataGenerationService.generateData(configJson);
        Test.stopTest();
        
        // Verify results
        List<Map<String, Object>> objectsList = (List<Map<String, Object>>)result.get('objects');
        Map<String, Object> accountData = null;
        for(Map<String, Object> objData : objectsList) {
            if('Account'.equals(objData.get('name'))) {
                accountData = objData;
                break;
            }
        }
        
        System.assertNotEquals(null, accountData, 'Should contain Account data');
        List<SObject> accounts = (List<SObject>)accountData.get('records');
        Account acc = (Account)accounts[0];
        
        System.assertNotEquals(null, acc.Name, 'Name should be populated');
        System.assertNotEquals(null, acc.NumberOfEmployees, 'NumberOfEmployees should be populated');
        System.assertNotEquals(null, acc.Website, 'Website should be populated');
        System.assertNotEquals(null, acc.Industry, 'Industry should be populated');
    }
    
    /**
     * Test relationship processing
     */
    @isTest
    static void testRelationshipProcessing() {
        // Create JSON with object relationships
        String configJson = '{"objects": [' +
            '{"name": "Account", "count": 2, "fields": [{"name": "Name", "type": "String"}]},' +
            '{"name": "Contact", "count": 3, "fields": [{"name": "LastName", "type": "String"}],' +
            ' "relationships": [{"childObject": "Contact", "parentObject": "Account", "field": "AccountId"}]}' +
            ']}';
        
        // Execute test
        Test.startTest();
        Map<String, Object> result = DataGenerationService.generateData(configJson);
        Test.stopTest();
        
        // Verify results
        List<Map<String, Object>> objectsList = (List<Map<String, Object>>)result.get('objects');
        
        // Find Account and Contact data
        Map<String, Object> accountData = null;
        Map<String, Object> contactData = null;
        
        for(Map<String, Object> objData : objectsList) {
            String objName = (String)objData.get('name');
            if('Account'.equals(objName)) {
                accountData = objData;
            } else if('Contact'.equals(objName)) {
                contactData = objData;
            }
        }
        
        System.assertNotEquals(null, accountData, 'Should contain Account data');
        System.assertNotEquals(null, contactData, 'Should contain Contact data');
        
        List<SObject> accounts = (List<SObject>)accountData.get('records');
        List<SObject> contacts = (List<SObject>)contactData.get('records');
        
        System.assertEquals(2, accounts.size(), 'Should create 2 Account records');
        System.assertEquals(3, contacts.size(), 'Should create 3 Contact records');
        
        // We can't verify AccountId was set since we're not inserting records,
        // but we can verify the service completes successfully
    }
    
    /**
     * Get a valid JSON configuration for testing
     */
    private static String getValidConfigJson() {
        return '{"context": {"locale": "en_US", "industry": "Technology"},' +
               '"objects": [' +
               '{"name": "Account", "count": 2, "fields": [' +
               '{"name": "Name", "type": "String", "length": 50},' +
               '{"name": "Description", "type": "String", "length": 1000}' +
               ']}' +
               ']}';
    }
} 