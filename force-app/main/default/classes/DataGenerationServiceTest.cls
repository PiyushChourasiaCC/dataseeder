/**
 * @description Test class for DataGenerationService
 * @author Generated with AI support
 */
@isTest
private class DataGenerationServiceTest {
    
    /**
     * @description Test the basic generateData method
     */
    @isTest
    static void testGenerateData() {
        // Create test data
        String configJson = createTestConfiguration();
        
        // Execute the method under test
        Test.startTest();
        Map<String, Object> result = DataGenerationService.generateData(configJson);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('objects'), 'Result should contain objects key');
        
        // Validate objects array
        List<Map<String, Object>> objects = (List<Map<String, Object>>) result.get('objects');
        System.assert(!objects.isEmpty(), 'Objects array should not be empty');
        
        // Validate first object
        Map<String, Object> accountObj = objects[0];
        System.assertEquals('Account', accountObj.get('name'), 'First object should be Account');
        
        // Validate records
        List<SObject> records = (List<SObject>) accountObj.get('records');
        System.assert(!records.isEmpty(), 'Account records should not be empty');
        
        // Validate record attributes
        SObject firstRecord = records[0];
        Map<String, Object> fieldsMap = firstRecord.getPopulatedFieldsAsMap();
        System.assert(fieldsMap.containsKey('Name'), 'Record should have Name field');
    }
    
    /**
     * @description Test the generation of data via LLM API with a valid configuration
     */
    @isTest
    static void testGenerateDataViaLLM() {
        // Create test data
        String configJson = createTestConfiguration();
        
        // Mock the LLM response
        Test.setMock(HttpCalloutMock.class, new LLMServiceMock());
        
        // Execute the method under test
        Test.startTest();
        Map<String, Object> result = DataGenerationService.generateDataViaLLM(configJson);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('objects'), 'Result should contain objects key');
        
        // Validate objects array
        List<Map<String, Object>> objects = (List<Map<String, Object>>) result.get('objects');
        System.assert(!objects.isEmpty(), 'Objects array should not be empty');
        
        // Validate first object
        Map<String, Object> accountObj = objects[0];
        System.assertEquals('Account', accountObj.get('name'), 'First object should be Account');
        
        // Validate records
        List<SObject> records = (List<SObject>) accountObj.get('records');
        System.assert(!records.isEmpty(), 'Account records should not be empty');
        
        // Validate record attributes
        SObject firstRecord = records[0];
        Map<String, Object> fieldsMap = firstRecord.getPopulatedFieldsAsMap();
        System.assert(fieldsMap.containsKey('Name'), 'Record should have Name field');
    }
    
    /**
     * @description Test the generateAndInsert method
     */
    @isTest
    static void testGenerateAndInsert() {
        // Create test data
        String configJson = createTestConfiguration();
        
        // Execute the method under test
        Test.startTest();
        Map<String, Object> result = DataGenerationService.generateAndInsert(configJson);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('success'), 'Result should contain success key');
        System.assert((Boolean)result.get('success'), 'Operation should be successful');
        
        // Check that records were inserted
        List<Account> accounts = [SELECT Id, Name, Industry FROM Account];
        System.assert(!accounts.isEmpty(), 'Accounts should have been inserted');
    }
    
    /**
     * @description Test the fallback mechanism when LLM API fails
     */
    @isTest
    static void testFallbackGeneration() {
        // Create test data
        String configJson = createTestConfiguration();
        
        // Mock an LLM failure response
        Test.setMock(HttpCalloutMock.class, new LLMServiceErrorMock());
        
        // Execute the method under test
        Test.startTest();
        Map<String, Object> result = DataGenerationService.generateDataViaLLM(configJson);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('objects'), 'Result should contain objects key');
        
        // Validate objects array
        List<Map<String, Object>> objects = (List<Map<String, Object>>) result.get('objects');
        System.assert(!objects.isEmpty(), 'Objects array should not be empty - fallback should have worked');
        
        // Validate fallback records
        Map<String, Object> accountObj = objects[0];
        List<SObject> records = (List<SObject>) accountObj.get('records');
        System.assert(!records.isEmpty(), 'Fallback records should have been generated');
        
        // Check that fallback naming pattern is used
        SObject firstRecord = records[0];
        String name = (String)firstRecord.get('Name');
        System.assert(name.startsWith('Account_'), 'Fallback naming pattern should be used');
    }
    
    /**
     * @description Test validation handling with invalid configuration
     */
    @isTest
    static void testInvalidConfiguration() {
        // Create invalid configuration (missing required fields)
        Map<String, Object> accountObj = new Map<String, Object>{
            'name' => 'Account',
            'count' => 2,
            'fields' => new List<Object>() // Empty fields array
        };
        
        Map<String, Object> config = new Map<String, Object>{
            'objects' => new List<Object>{accountObj}
        };
        
        String invalidConfigJson = JSON.serialize(config);
        
        // Test should throw an exception
        Test.startTest();
        try {
            Map<String, Object> result = DataGenerationService.generateData(invalidConfigJson);
            System.assert(false, 'Should have thrown an exception for invalid configuration');
        } catch (AuraHandledException e) {
            String errorMsg = e.getMessage();
            System.assert(errorMsg.contains('Error') || errorMsg.contains('error'), 
                         'Exception message should contain error information: ' + errorMsg);
        }
        Test.stopTest();
    }
    
    /**
     * @description Test with invalid JSON
     */
    @isTest
    static void testInvalidJson() {
        String invalidJson = '{not valid json:}';
        
        Test.startTest();
        try {
            Map<String, Object> result = DataGenerationService.generateData(invalidJson);
            System.assert(false, 'Should have thrown an exception for invalid JSON');
        } catch (AuraHandledException e) {
            String errorMsg = e.getMessage();
            System.assert(errorMsg.contains('Invalid JSON'), 
                         'Exception message should mention invalid JSON: ' + errorMsg);
        }
        Test.stopTest();
    }
    
    /**
     * @description Test with relationship configuration
     */
    @isTest
    static void testRelationships() {
        // Create configuration with parent-child relationship
        Map<String, Object> accountFields = new Map<String, Object>{
            'name' => 'Name',
            'type' => 'String',
            'required' => true
        };
        
        Map<String, Object> contactFields = new Map<String, Object>{
            'name' => 'LastName',
            'type' => 'String',
            'required' => true
        };
        
        Map<String, Object> relationshipField = new Map<String, Object>{
            'name' => 'AccountId',
            'type' => 'String'
        };
        
        Map<String, Object> relationship = new Map<String, Object>{
            'childObject' => 'Contact',
            'parentObject' => 'Account',
            'field' => 'AccountId'
        };
        
        Map<String, Object> accountObj = new Map<String, Object>{
            'name' => 'Account',
            'count' => 2,
            'fields' => new List<Object>{accountFields}
        };
        
        Map<String, Object> contactObj = new Map<String, Object>{
            'name' => 'Contact',
            'count' => 3,
            'fields' => new List<Object>{contactFields, relationshipField},
            'relationships' => new List<Object>{relationship}
        };
        
        Map<String, Object> config = new Map<String, Object>{
            'objects' => new List<Object>{accountObj, contactObj}
        };
        
        String configJson = JSON.serialize(config);
        
        // Execute the method under test
        Test.startTest();
        Map<String, Object> result = DataGenerationService.generateAndInsert(configJson);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(true, result.get('success'), 'Operation should be successful');
        
        // Check records were created with relationship
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact];
        System.assert(!contacts.isEmpty(), 'Contacts should have been created');
        
        // Check at least some contacts have account IDs
        Boolean hasAccountRelationship = false;
        for (Contact c : contacts) {
            if (c.AccountId != null) {
                hasAccountRelationship = true;
                break;
            }
        }
        System.assert(hasAccountRelationship, 'At least one contact should have an account relationship');
    }
    
    /**
     * @description Test with complex field configurations including different field types
     */
    @isTest
    static void testComplexFields() {
        // Create complex field configurations
        List<Map<String, Object>> fields = new List<Map<String, Object>>{
            new Map<String, Object>{
                'name' => 'Name',
                'type' => 'String',
                'required' => true
            },
            new Map<String, Object>{
                'name' => 'AnnualRevenue',
                'type' => 'Number',
                'minValue' => 1000,
                'maxValue' => 1000000
            },
            new Map<String, Object>{
                'name' => 'Industry',
                'type' => 'Picklist',
                'picklistValues' => new List<Object>{
                    new Map<String, Object>{'label' => 'Technology', 'value' => 'Technology'},
                    new Map<String, Object>{'label' => 'Finance', 'value' => 'Finance'},
                    new Map<String, Object>{'label' => 'Healthcare', 'value' => 'Healthcare'}
                }
            },
            new Map<String, Object>{
                'name' => 'IsActive',
                'type' => 'Boolean'
            }
        };
        
        Map<String, Object> accountObj = new Map<String, Object>{
            'name' => 'Account',
            'count' => 5,
            'fields' => fields
        };
        
        Map<String, Object> config = new Map<String, Object>{
            'objects' => new List<Object>{accountObj},
            'context' => new Map<String, Object>{
                'locale' => 'en_US',
                'industry' => 'Technology',
                'region' => 'North America'
            }
        };
        
        String configJson = JSON.serialize(config);
        
        // Execute the method under test
        Test.startTest();
        Map<String, Object> result = DataGenerationService.generateData(configJson);
        Test.stopTest();
        
        // Verify results
        List<Map<String, Object>> objects = (List<Map<String, Object>>) result.get('objects');
        Map<String, Object> accountData = objects[0];
        List<SObject> records = (List<SObject>) accountData.get('records');
        
        // Check all fields are populated correctly
        for (SObject record : records) {
            // Check string field
            System.assertNotEquals(null, record.get('Name'), 'Name should be populated');
            
            // Check number field
            Object revenue = record.get('AnnualRevenue');
            if (revenue != null) {
                Decimal revenueValue = (Decimal)revenue;
                System.assert(revenueValue >= 1000 && revenueValue <= 1000000, 
                             'Revenue should be within range: ' + revenueValue);
            }
            
            // We can't check picklist and boolean values specifically as they're random,
            // but we can check they're the right types when present
            Object industry = record.get('Industry');
            if (industry != null) {
                System.assert(industry instanceof String, 'Industry should be a string');
            }
            
            Object isActive = record.get('IsActive');
            if (isActive != null) {
                System.assert(isActive instanceof Boolean, 'IsActive should be a boolean');
            }
        }
    }
    
    /**
     * @description Create a test configuration JSON for account generation
     */
    private static String createTestConfiguration() {
        Map<String, Object> fieldName = new Map<String, Object>{
            'name' => 'Name',
            'type' => 'String',
            'required' => true
        };
        
        Map<String, Object> fieldIndustry = new Map<String, Object>{
            'name' => 'Industry',
            'type' => 'Picklist',
            'picklistValues' => new List<Object>{
                new Map<String, Object>{'label' => 'Technology', 'value' => 'Technology'},
                new Map<String, Object>{'label' => 'Finance', 'value' => 'Finance'}
            }
        };
        
        Map<String, Object> accountObj = new Map<String, Object>{
            'name' => 'Account',
            'count' => 2,
            'fields' => new List<Object>{fieldName, fieldIndustry}
        };
        
        Map<String, Object> config = new Map<String, Object>{
            'objects' => new List<Object>{accountObj},
            'context' => new Map<String, Object>{
                'locale' => 'en_US',
                'industry' => 'Technology'
            }
        };
        
        return JSON.serialize(config);
    }
    
    /**
     * @description Mock class for LLMService successful responses
     */
    private class LLMServiceMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            
            // Create mock response data
            Map<String, Object> mockData = new Map<String, Object>{
                'Name' => 'Test Account',
                'Industry' => 'Technology'
            };
            
            response.setBody(JSON.serialize(mockData));
            return response;
        }
    }
    
    /**
     * @description Mock class for LLMService error responses
     */
    private class LLMServiceErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"error": "API Error"}');
            return response;
        }
    }
    
    /**
     * @description Test specifically for Account record generation with minimal configuration
     */
    @isTest
    static void testAccountGeneration() {
        // Create minimal Account configuration
        Map<String, Object> accountObj = new Map<String, Object>{
            'name' => 'Account',
            'count' => 1,
            'fields' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'Name',
                    'type' => 'String'
                }
            }
        };
        
        Map<String, Object> config = new Map<String, Object>{
            'objects' => new List<Object>{accountObj},
            'context' => new Map<String, Object>{
                'locale' => 'en_US',
                'industry' => 'Technology'
            }
        };
        
        String configJson = JSON.serialize(config);
        
        // Execute the method under test
        Test.startTest();
        Map<String, Object> result = DataGenerationService.generateAndInsert(configJson);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('success'), 'Result should contain success key');
        System.assert((Boolean)result.get('success'), 'Operation should be successful');
        
        // Check Account was created
        List<Account> accounts = [SELECT Id, Name, Industry FROM Account];
        System.assert(!accounts.isEmpty(), 'At least one Account should have been created');
        System.assertNotEquals(null, accounts[0].Name, 'Account should have a Name');
        
        // Verify Account record count in result
        Map<String, Integer> recordCounts = (Map<String, Integer>)result.get('insertedRecordCounts');
        System.assert(recordCounts.containsKey('Account'), 'Result should include Account record count');
        System.assertEquals(1, recordCounts.get('Account'), 'Should have inserted 1 Account record');
    }
    
    /**
     * @description Test fallback creation when no configuration is provided for Account
     */
    @isTest
    static void testAccountFallbackGeneration() {
        // Create configuration with empty fields
        Map<String, Object> accountObj = new Map<String, Object>{
            'name' => 'Account',
            'count' => 1,
            'fields' => new List<Object>()  // Empty fields list should trigger fallback
        };
        
        Map<String, Object> config = new Map<String, Object>{
            'objects' => new List<Object>{accountObj},
            'context' => new Map<String, Object>{
                'industry' => 'Technology'
            }
        };
        
        String configJson = JSON.serialize(config);
        
        // Execute the method
        Test.startTest();
        Map<String, Object> result = DataGenerationService.generateData(configJson);
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, result, 'Result should not be null');
        List<Map<String, Object>> objects = (List<Map<String, Object>>) result.get('objects');
        System.assert(!objects.isEmpty(), 'Should have generated at least one object type');
        
        Map<String, Object> accountData = objects[0];
        List<SObject> records = (List<SObject>) accountData.get('records');
        System.assertNotEquals(null, records, 'Should have generated some Account records');
        System.assert(!records.isEmpty(), 'Should have at least one Account record');
        
        // Verify the Account has a Name
        SObject account = records[0];
        System.assertNotEquals(null, account.get('Name'), 'Account should have a Name field');
    }
} 