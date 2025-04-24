/**
 * Test class for ContextSettingsService
 * 
 * @author Your Name
 * @date Today's Date
 */
@isTest
public class ContextSettingsServiceTest {
    
    @isTest
    static void testGetContextFromJson() {
        // Test with valid JSON
        String validJson = '{"locale": "en_US", "industry": "Healthcare", "region": "West"}';
        Map<String, Object> context = ContextSettingsService.getContextFromJson(validJson);
        
        System.assertEquals('en_US', context.get('locale'), 'Locale should match the JSON value');
        System.assertEquals('Healthcare', context.get('industry'), 'Industry should match the JSON value');
        System.assertEquals('West', context.get('region'), 'Region should match the JSON value');
        
        // Test with null JSON
        Map<String, Object> defaultContext = ContextSettingsService.getContextFromJson(null);
        System.assertEquals('en_US', defaultContext.get('locale'), 'Default locale should be en_US');
        System.assertEquals('Technology', defaultContext.get('industry'), 'Default industry should be Technology');
        System.assertEquals('North America', defaultContext.get('region'), 'Default region should be North America');
        
        // Test with invalid JSON
        Map<String, Object> invalidContext = ContextSettingsService.getContextFromJson('{invalid:json}');
        System.assertEquals('en_US', invalidContext.get('locale'), 'Should fall back to default locale');
        System.assertEquals('Technology', invalidContext.get('industry'), 'Should fall back to default industry');
        System.assertEquals('North America', invalidContext.get('region'), 'Should fall back to default region');
    }
    
    @isTest
    static void testGetContextValue() {
        Map<String, Object> context = new Map<String, Object>{
            'key1' => 'value1',
            'key2' => 123,
            'key3' => true
        };
        
        // Test existing values
        Object value1 = ContextSettingsService.getContextValue(context, 'key1', 'default');
        System.assertEquals('value1', value1, 'Should return the correct value for key1');
        
        Object value2 = ContextSettingsService.getContextValue(context, 'key2', 0);
        System.assertEquals(123, value2, 'Should return the correct value for key2');
        
        Object value3 = ContextSettingsService.getContextValue(context, 'key3', false);
        System.assertEquals(true, value3, 'Should return the correct value for key3');
        
        // Test default values
        Object defaultValue = ContextSettingsService.getContextValue(context, 'nonexistent', 'default');
        System.assertEquals('default', defaultValue, 'Should return the default value for non-existent key');
        
        // Test with null context
        Object nullContextValue = ContextSettingsService.getContextValue(null, 'key', 'default');
        System.assertEquals('default', nullContextValue, 'Should return default when context is null');
    }
    
    @isTest
    static void testApplyContextToRecord() {
        // Create test account
        Account acc = new Account(Name = 'Test Account');
        
        // Create context
        Map<String, Object> context = new Map<String, Object>{
            'industry' => 'Healthcare',
            'region' => 'West',
            'employeeCount' => 500
        };
        
        // Create field mappings
        Map<String, String> fieldMappings = new Map<String, String>{
            'industry' => 'Industry',
            'employeeCount' => 'NumberOfEmployees'
        };
        
        // Apply context
        ContextSettingsService.applyContextToRecord(acc, context, fieldMappings);
        
        // Verify fields were updated
        System.assertEquals('Healthcare', acc.Industry, 'Industry should be updated from context');
        System.assertEquals(500, acc.NumberOfEmployees, 'NumberOfEmployees should be updated from context');
        
        // Test with null parameters
        Account nullAcc = new Account(Name = 'Test Null');
        ContextSettingsService.applyContextToRecord(nullAcc, null, fieldMappings);
        ContextSettingsService.applyContextToRecord(nullAcc, context, null);
        // Should not throw exceptions
    }
    
    @isTest
    static void testGetIndustrySpecificValues() {
        // Test Healthcare industry
        Map<String, Object> healthcareContext = new Map<String, Object>{
            'industry' => 'Healthcare'
        };
        
        List<String> healthcareProducts = ContextSettingsService.getIndustrySpecificValues('products', healthcareContext);
        System.assert(healthcareProducts.contains('Medical Equipment'), 'Healthcare products should include Medical Equipment');
        System.assert(healthcareProducts.contains('Pharmaceuticals'), 'Healthcare products should include Pharmaceuticals');
        
        // Test Technology industry
        Map<String, Object> techContext = new Map<String, Object>{
            'industry' => 'Technology'
        };
        
        List<String> techProducts = ContextSettingsService.getIndustrySpecificValues('products', techContext);
        System.assert(techProducts.contains('Software'), 'Technology products should include Software');
        System.assert(techProducts.contains('Hardware'), 'Technology products should include Hardware');
        
        // Test default industry (Technology)
        Map<String, Object> defaultContext = new Map<String, Object>{
            'industry' => 'Unknown'
        };
        
        List<String> defaultProducts = ContextSettingsService.getIndustrySpecificValues('products', defaultContext);
        System.assert(defaultProducts.contains('Software'), 'Default products should include Software');
        
        // Test unknown value type
        List<String> unknownValueType = ContextSettingsService.getIndustrySpecificValues('unknown', techContext);
        System.assert(unknownValueType.isEmpty(), 'Unknown value type should return empty list');
    }
    
    @isTest
    static void testGetRegionalFormat() {
        // Test North America region
        Map<String, Object> naContext = new Map<String, Object>{
            'region' => 'North America',
            'locale' => 'en_US'
        };
        
        String naPhone = ContextSettingsService.getRegionalFormat('5551234567', 'phone', naContext);
        System.assertEquals('(555) 123-4567', naPhone, 'North America phone format should be (XXX) XXX-XXXX');
        
        String naCurrency = ContextSettingsService.getRegionalFormat('1000', 'currency', naContext);
        System.assertEquals('$1,000.00', naCurrency, 'North America currency format should have $ prefix');
        
        // Test Europe region
        Map<String, Object> euContext = new Map<String, Object>{
            'region' => 'Europe',
            'locale' => 'en_GB'
        };
        
        String euPhone = ContextSettingsService.getRegionalFormat('5551234567', 'phone', euContext);
        System.assertEquals('+44 555 123 4567', euPhone, 'Europe phone format should be +44 XXX XXX XXXX');
        
        String euCurrency = ContextSettingsService.getRegionalFormat('1000', 'currency', euContext);
        System.assertEquals('£1,000.00', euCurrency, 'Europe currency format should have £ prefix');
        
        // Test default format (returns original value)
        String defaultFormat = ContextSettingsService.getRegionalFormat('test', 'unknown', naContext);
        System.assertEquals('test', defaultFormat, 'Unknown format type should return original value');
    }
} 