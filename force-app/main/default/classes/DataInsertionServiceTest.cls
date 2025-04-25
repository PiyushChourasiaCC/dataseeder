/**
 * Test class for DataInsertionService
 * 
 * Covers record insertion, transaction management, and error handling
 */
@isTest
private class DataInsertionServiceTest {
    
    /**
     * Test successful insertion of records
     */
    @isTest
    static void testSuccessfulInsertion() {
        // Create test records that don't depend on pre-inserted Accounts
        Map<String, List<SObject>> testRecords = new Map<String, List<SObject>>();
        
        // Create Account records
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Success Test Account 1'),
            new Account(Name = 'Success Test Account 2')
        };
        testRecords.put('Account', accounts);
        
        // Create Contact records (will be linked in the service through processRelationships)
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'Success Test Contact 1'),
            new Contact(LastName = 'Success Test Contact 2'),
            new Contact(LastName = 'Success Test Contact 3')
        };
        testRecords.put('Contact', contacts);
        
        // Execute test
        Test.startTest();
        DataInsertionService.DataInsertionResult result = DataInsertionService.insertRecords(testRecords);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(true, result.success, 'Insertion should be successful');
        System.assertEquals(0, result.errors.size(), 'No errors should be present');
        System.assertEquals(2, result.insertedRecordIds.size(), 'Should have IDs for both object types');
        
        // Verify Account records were inserted
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Success Test%'];
        System.assertEquals(2, insertedAccounts.size(), 'Two account records should be inserted');
        
        // Verify Contact records were inserted
        List<Contact> insertedContacts = [SELECT Id, LastName FROM Contact WHERE LastName LIKE 'Success Test%'];
        System.assertEquals(3, insertedContacts.size(), 'Three contact records should be inserted');
    }
    
    /**
     * Test handling of invalid records
     */
    @isTest
    static void testInvalidRecords() {
        // Create map with some invalid records (missing required fields)
        Map<String, List<SObject>> records = new Map<String, List<SObject>>();
        
        // Add valid Account
        Account validAccount = new Account(Name = 'Test Account');
        records.put('Account', new List<SObject>{validAccount});
        
        // Add invalid Contact (missing LastName)
        Contact invalidContact = new Contact();
        records.put('Contact', new List<SObject>{invalidContact});
        
        // Execute test
        Test.startTest();
        DataInsertionService.DataInsertionResult result = DataInsertionService.insertRecords(records);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(false, result.success, 'Insertion should fail due to invalid records');
        System.assertNotEquals(0, result.errors.size(), 'Errors should be present');
        System.assertEquals(0, result.insertedRecordIds.size(), 'No IDs should be returned due to rollback');
        
        // Verify nothing was inserted (transaction rollback)
        List<Account> insertedAccounts = [SELECT Id FROM Account];
        System.assertEquals(0, insertedAccounts.size(), 'No accounts should be inserted due to rollback');
    }
    
    /**
     * Test batch processing for large record sets
     */
    @isTest
    static void testBatchProcessing() {
        // Create a large set of records (above batch size)
        Map<String, List<SObject>> records = new Map<String, List<SObject>>();
        List<Account> accounts = new List<Account>();
        
        for (Integer i = 0; i < 15; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        
        records.put('Account', accounts);
        
        // Execute test
        Test.startTest();
        DataInsertionService.DataInsertionResult result = DataInsertionService.insertRecords(records);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(true, result.success, 'Batch insertion should succeed');
        System.assertEquals(15, result.insertedRecordIds.get('Account').size(), 'All records should be inserted');
        
        // Verify correct number of records were inserted
        List<Account> insertedAccounts = [SELECT Id FROM Account];
        System.assertEquals(15, insertedAccounts.size(), '15 accounts should be inserted');
    }
    
    /**
     * Test the asynchronous insertion method
     */
    @isTest
    static void testAsyncInsertion() {
        // Create test records with a different approach for async
        Map<String, List<SObject>> testRecords = new Map<String, List<SObject>>();
        
        // Create Account records for async
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Async Test Account 1'),
            new Account(Name = 'Async Test Account 2')
        };
        testRecords.put('Account', accounts);
        
        // Create Contact records for async
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'Async Test Contact 1'),
            new Contact(LastName = 'Async Test Contact 2'),
            new Contact(LastName = 'Async Test Contact 3')
        };
        testRecords.put('Contact', contacts);
        
        String recordsJson = JSON.serialize(testRecords);
        
        // Execute test
        Test.startTest();
        DataInsertionService.insertRecordsAsync(recordsJson);
        Test.stopTest(); // This forces async jobs to complete
        
        // Verify records were inserted
        List<Account> insertedAccounts = [SELECT Id FROM Account WHERE Name LIKE 'Async Test%'];
        List<Contact> insertedContacts = [SELECT Id FROM Contact WHERE LastName LIKE 'Async Test%'];
        
        System.assertEquals(2, insertedAccounts.size(), 'Two accounts should be inserted asynchronously');
        System.assertEquals(3, insertedContacts.size(), 'Three contacts should be inserted asynchronously');
    }
    
    /**
     * Test error handling with mixed valid/invalid records
     */
    @isTest
    static void testMixedRecordValidation() {
        // Create map with mixed valid and invalid records
        Map<String, List<SObject>> records = new Map<String, List<SObject>>();
        
        // Add valid and invalid Accounts
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Valid Account 1'),
            new Account(), // Invalid - missing required Name
            new Account(Name = 'Valid Account 2')
        };
        records.put('Account', accounts);
        
        // Execute test
        Test.startTest();
        DataInsertionService.DataInsertionResult result = DataInsertionService.insertRecords(records);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(false, result.success, 'Insertion should fail due to invalid records');
        System.assertNotEquals(0, result.errors.size(), 'Errors should be present');
        
        // Verify transaction was rolled back
        List<Account> insertedAccounts = [SELECT Id FROM Account];
        System.assertEquals(0, insertedAccounts.size(), 'No accounts should be inserted due to rollback');
    }
    
    /**
     * Test insertion order determination
     */
    @isTest
    static void testInsertionOrder() {
        // Create records with standard and custom objects
        Map<String, List<SObject>> records = new Map<String, List<SObject>>();
        
        // Add various object types in random order
        records.put('Contact', new List<SObject>{new Contact(LastName = 'Test Contact')});
        records.put('Account', new List<SObject>{new Account(Name = 'Test Account')});
        records.put('Lead', new List<SObject>{new Lead(LastName = 'Test Lead', Company = 'Test Company')});
        records.put('DataSeederTemplate__c', new List<SObject>{
            Schema.getGlobalDescribe().get('DataSeederTemplate__c').newSObject()
        });
        
        // Execute test - we can't directly test the private determineInsertionOrder method,
        // but we can verify the service works correctly with multiple object types
        Test.startTest();
        DataInsertionService.DataInsertionResult result = DataInsertionService.insertRecords(records);
        Test.stopTest();
        
        // Verify results - if insertion order is wrong, the operation would fail
        System.assertEquals(true, result.success, 'Insertion with multiple object types should succeed');
        System.assertEquals(4, result.insertedRecordIds.size(), 'All object types should be inserted');
    }
    
    /**
     * Helper method to create test records with pre-linked Contacts
     */
    private static Map<String, List<SObject>> createTestRecords() {
        Map<String, List<SObject>> records = new Map<String, List<SObject>>();
        
        // Create Accounts first
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Test Account 1'),
            new Account(Name = 'Test Account 2')
        };
        
        // Insert accounts to get their IDs
        insert accounts;
        
        records.put('Account', accounts);
        
        // Create Contacts linked to the first account
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'Test Contact 1', AccountId = accounts[0].Id),
            new Contact(LastName = 'Test Contact 2', AccountId = accounts[0].Id),
            new Contact(LastName = 'Test Contact 3', AccountId = accounts[1].Id)
        };
        records.put('Contact', contacts);
        
        return records;
    }
    
    /**
     * Test the new record sanitization functionality
     */
    @isTest
    static void testRecordSanitization() {
        // Create a map with records that have attributes
        Map<String, List<SObject>> records = new Map<String, List<SObject>>();
        
        // Create an Account with attributes that might cause issues
        Account acct = new Account(Name = 'Sanitization Test Account');
        
        // Add custom attributes through JSON serialization/deserialization
        String jsonStr = JSON.serialize(acct);
        Map<String, Object> acctMap = (Map<String, Object>)JSON.deserializeUntyped(jsonStr);
        
        // Modify attributes
        Map<String, Object> attrs = new Map<String, Object>{
            'type' => 'Account',
            'custom' => 'This should be stripped'
        };
        acctMap.put('attributes', attrs);
        
        // Convert back to SObject
        String modifiedJson = JSON.serialize(acctMap);
        Account modifiedAcct = (Account)JSON.deserialize(modifiedJson, Account.class);
        
        records.put('Account', new List<SObject>{modifiedAcct});
        
        // Execute test
        Test.startTest();
        Map<String, Object> result = DataInsertionService.insertRecordsInternal(records);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(true, result.get('success'), 'Sanitization should allow successful insertion');
        
        Map<String, List<Id>> insertedIds = (Map<String, List<Id>>)result.get('insertedRecordIds');
        System.assert(insertedIds.containsKey('Account'), 'Should have inserted Account records');
        System.assertEquals(1, insertedIds.get('Account').size(), 'Should have inserted 1 Account record');
        
        // Verify the record was inserted with correct data
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name = 'Sanitization Test Account'];
        System.assertEquals(1, insertedAccounts.size(), 'Account should be inserted with correct name');
    }
    
    /**
     * Test automatic field validation
     */
    @isTest
    static void testFieldValidation() {
        // Create a Contact without required LastName
        Contact invalidContact = new Contact();
        
        // But include a valid Account
        Account validAccount = new Account(Name = 'Validation Test Account');
        
        Map<String, List<SObject>> records = new Map<String, List<SObject>>();
        records.put('Contact', new List<SObject>{invalidContact});
        records.put('Account', new List<SObject>{validAccount});
        
        // Execute test
        Test.startTest();
        Map<String, Object> result = DataInsertionService.insertRecordsInternal(records);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(false, result.get('success'), 'Validation should fail with invalid Contact');
        
        List<String> errors = (List<String>)result.get('errors');
        Boolean foundValidationError = false;
        for (String error : errors) {
            if (error.contains('LastName')) {
                foundValidationError = true;
                break;
            }
        }
        System.assert(foundValidationError, 'Should have error about missing LastName');
        
        // Verify no records were inserted due to rollback
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'Validation Test Account'];
        System.assertEquals(0, accounts.size(), 'No accounts should be inserted due to rollback');
    }
    
    /**
     * Test Account specific handling where Name is automatically provided
     */
    @isTest
    static void testAccountNameHandling() {
        // Create an Account without a Name
        Account acct = new Account();
        // Intentionally not setting Name
        
        Map<String, List<SObject>> records = new Map<String, List<SObject>>();
        records.put('Account', new List<SObject>{acct});
        
        // Execute test
        Test.startTest();
        Map<String, Object> result = DataInsertionService.insertRecordsInternal(records);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(true, result.get('success'), 'Account insertion should succeed with auto-generated Name');
        
        // Verify Account was created
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account];
        System.assertEquals(1, insertedAccounts.size(), 'Account should be inserted');
        System.assertNotEquals(null, insertedAccounts[0].Name, 'Account should have auto-generated Name');
        System.assert(insertedAccounts[0].Name.startsWith('Account '), 'Account should have expected name pattern');
    }
} 