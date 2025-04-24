/**
 * @description Test class for DataSeederUtility
 * @author Claude AI
 * @date 2023-10-17
 */
@isTest
public class DataSeederUtilityTest {
    
    @isTest
    static void testValidateFieldValues() {
        // Setup test data
        String objectName = 'Account';
        Map<String, Object> validValues = new Map<String, Object>{
            'Name' => 'Test Account',
            'NumberOfEmployees' => 100,
            'Phone' => '1234567890',
            'Website' => 'https://www.example.com'
        };
        
        Map<String, Object> invalidValues = new Map<String, Object>{
            'Name' => '',  // Empty name
            'NumberOfEmployees' => 'abc',  // String instead of number
            'Phone' => '12',  // Too short
            'Website' => 'not-a-url'  // Invalid URL
        };
        
        // Test valid values
        Test.startTest();
        Map<String, String> validResult = DataSeederUtility.validateFieldValues(objectName, validValues);
        System.assertEquals(0, validResult.size(), 'Valid values should not produce errors');
        
        // Test invalid values
        Map<String, String> invalidResult = DataSeederUtility.validateFieldValues(objectName, invalidValues);
        System.assert(invalidResult.size() > 0, 'Invalid values should produce errors');
        System.assert(invalidResult.containsKey('NumberOfEmployees'), 'Should have error for NumberOfEmployees');
        System.assert(invalidResult.containsKey('Website'), 'Should have error for Website');
        Test.stopTest();
    }
    
    @isTest
    static void testValidateValueForFieldType() {
        // This is a private method, so we'll test it indirectly through validateFieldValues
        // Setup test data with specific field types to test
        String objectName = 'Account';
        
        // Test with a mix of types
        Map<String, Object> mixedValues = new Map<String, Object>{
            'Name' => 'Test Account',  // Valid string
            'NumberOfEmployees' => 100,  // Valid integer
            'Website' => 'https://example.com',  // Valid URL
            'Phone' => '1234567890'  // Valid phone
        };
        
        Test.startTest();
        // We're mainly checking if the method runs without exceptions
        Map<String, String> result = DataSeederUtility.validateFieldValues(objectName, mixedValues);
        Test.stopTest();
        
        // We don't make specific assertions because field validation details depend on field metadata
        // which can vary between orgs
        System.assertEquals(0, result.size(), 'Valid values should not produce errors');
    }
    
    @isTest
    static void testFormatRecordsForDisplay() {
        // Setup test data
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Test Account 1', Industry = 'Technology', Phone = '1234567890'),
            new Account(Name = 'Test Account 2', Industry = 'Healthcare', Phone = '0987654321')
        };
        
        Test.startTest();
        List<Map<String, Object>> formattedRecords = DataSeederUtility.formatRecordsForDisplay(accounts);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(2, formattedRecords.size(), 'Should format 2 records');
        System.assertEquals('Test Account 1', formattedRecords[0].get('Name'), 'First record name should match');
        System.assertEquals('Technology', formattedRecords[0].get('Industry'), 'First record industry should match');
        System.assertEquals('Test Account 2', formattedRecords[1].get('Name'), 'Second record name should match');
        System.assertEquals('Healthcare', formattedRecords[1].get('Industry'), 'Second record industry should match');
    }
    
    @isTest
    static void testSanitizeRecordsForInsertion() {
        // Setup test data with extra fields that shouldn't be in the final object
        Map<String, Object> record1 = new Map<String, Object>{
            'Name' => 'Test Account 1',
            'Industry' => 'Technology',
            'Phone' => '1234567890',
            'NonExistentField' => 'This should be removed'
        };
        
        Map<String, Object> record2 = new Map<String, Object>{
            'Name' => 'Test Account 2',
            'Industry' => 'Healthcare',
            'Phone' => '0987654321',
            'AnotherNonExistentField' => 'This should also be removed'
        };
        
        List<Map<String, Object>> records = new List<Map<String, Object>>{record1, record2};
        
        Test.startTest();
        List<Map<String, Object>> sanitizedRecords = DataSeederUtility.sanitizeRecordsForInsertion('Account', records);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(2, sanitizedRecords.size(), 'Should have 2 sanitized records');
        
        // Verify fields were properly sanitized
        System.assertEquals('Test Account 1', sanitizedRecords[0].get('Name'), 'First account name should match');
        System.assertEquals('Technology', sanitizedRecords[0].get('Industry'), 'First account industry should match');
        System.assertEquals('Test Account 2', sanitizedRecords[1].get('Name'), 'Second account name should match');
        System.assertEquals('Healthcare', sanitizedRecords[1].get('Industry'), 'Second account industry should match');
        
        // Verify invalid fields were removed
        System.assertEquals(false, sanitizedRecords[0].containsKey('NonExistentField'), 'Invalid fields should be removed');
        System.assertEquals(false, sanitizedRecords[1].containsKey('AnotherNonExistentField'), 'Invalid fields should be removed');
    }
    
    @isTest
    static void testConvertToFieldType() {
        // This is a private method, so we'll test it indirectly through sanitizeRecordsForInsertion
        // Setup test data with fields that need conversion
        Map<String, Object> record = new Map<String, Object>{
            'Name' => 'Test Account',
            'NumberOfEmployees' => '100',  // String needs conversion to Integer
            'AnnualRevenue' => '1000000'  // String needs conversion to Currency
        };
        
        List<Map<String, Object>> records = new List<Map<String, Object>>{record};
        
        Test.startTest();
        // We're testing the method indirectly, mainly checking if it converts values without exceptions
        List<Map<String, Object>> sanitizedRecords = DataSeederUtility.sanitizeRecordsForInsertion('Account', records);
        Test.stopTest();
        
        // Check that the values were properly converted
        System.assertEquals('Test Account', sanitizedRecords[0].get('Name'), 'Name should be preserved as string');
        
        // These assertions depend on the field types in your org
        // If NumberOfEmployees is an Integer field in your org:
        if (sanitizedRecords[0].containsKey('NumberOfEmployees')) {
            Object empValue = sanitizedRecords[0].get('NumberOfEmployees');
            System.assert(empValue instanceof Integer || empValue instanceof Decimal, 
                         'NumberOfEmployees should be converted to a number type');
        }
        
        // If AnnualRevenue is a Currency field in your org:
        if (sanitizedRecords[0].containsKey('AnnualRevenue')) {
            Object revValue = sanitizedRecords[0].get('AnnualRevenue');
            System.assert(revValue instanceof Decimal, 
                         'AnnualRevenue should be converted to a Decimal type');
        }
    }
} 