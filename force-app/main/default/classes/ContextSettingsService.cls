/**
 * Service class for managing context settings in Apex
 * 
 * This class provides methods to retrieve and apply context settings
 * for data generation and other processes that need contextual awareness
 */
public with sharing class ContextSettingsService {
    
    // Default context settings
    private static final Map<String, Object> DEFAULT_SETTINGS = new Map<String, Object>{
        'locale' => 'en_US',
        'industry' => 'Technology',
        'region' => 'North America'
    };
    
    /**
     * Get context settings from a JSON string
     * 
     * @param jsonConfig JSON configuration string containing context settings
     * @return Map<String, Object> Parsed context settings
     */
    public static Map<String, Object> getContextFromJson(String jsonConfig) {
        if (String.isBlank(jsonConfig)) {
            return new Map<String, Object>(DEFAULT_SETTINGS);
        }
        
        try {
            Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(jsonConfig);
            
            // Extract context settings if they exist
            if (configMap.containsKey('context')) {
                return (Map<String, Object>) configMap.get('context');
            } else {
                return new Map<String, Object>(DEFAULT_SETTINGS);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error parsing context settings: ' + e.getMessage());
            return new Map<String, Object>(DEFAULT_SETTINGS);
        }
    }
    
    /**
     * Get a specific context setting value
     * 
     * @param context The context settings map
     * @param key The setting key to retrieve
     * @param defaultValue Default value if setting is not found
     * @return Object The setting value or default value
     */
    public static Object getContextValue(Map<String, Object> context, String key, Object defaultValue) {
        if (context == null || !context.containsKey(key)) {
            return defaultValue;
        }
        return context.get(key);
    }
    
    /**
     * Apply context settings to a record based on field mappings
     * 
     * @param record The SObject record to update
     * @param context The context settings
     * @param fieldMappings Map of context keys to field API names
     * @return SObject The updated record
     */
    public static SObject applyContextToRecord(SObject record, Map<String, Object> context, 
                                           Map<String, String> fieldMappings) {
        if (record == null || context == null || fieldMappings == null) {
            return record;
        }
        
        for (String contextKey : fieldMappings.keySet()) {
            String fieldName = fieldMappings.get(contextKey);
            
            if (context.containsKey(contextKey)) {
                Object value = context.get(contextKey);
                
                try {
                    record.put(fieldName, value);
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'Error setting field ' + fieldName + 
                                 ' with context value: ' + e.getMessage());
                }
            }
        }
        
        return record;
    }
    
    /**
     * Get industry-specific values based on context
     * 
     * @param valueType The type of values to retrieve (e.g., 'products', 'services')
     * @param context The context settings
     * @return List<String> List of industry-specific values
     */
    public static List<String> getIndustrySpecificValues(String valueType, Map<String, Object> context) {
        String industry = (String) getContextValue(context, 'industry', 'General');
        
        Map<String, Map<String, List<String>>> industryValues = new Map<String, Map<String, List<String>>>{
            'products' => new Map<String, List<String>>{
                'Technology' => new List<String>{'Software', 'Hardware', 'Cloud Services', 'AI Solutions'},
                'Financial Services' => new List<String>{'Loans', 'Credit Cards', 'Investment Plans', 'Insurance'},
                'Healthcare' => new List<String>{'Medical Devices', 'Pharmaceuticals', 'Healthcare Plans'},
                'Retail' => new List<String>{'Apparel', 'Electronics', 'Home Goods', 'Groceries'}
            },
            'services' => new Map<String, List<String>>{
                'Technology' => new List<String>{'IT Consulting', 'Cloud Implementation', 'Software Development'},
                'Financial Services' => new List<String>{'Financial Planning', 'Investment Advisory', 'Banking'},
                'Healthcare' => new List<String>{'Patient Care', 'Medical Consulting', 'Health Insurance'},
                'Retail' => new List<String>{'Customer Service', 'Delivery', 'Installation'}
            }
        };
        
        if (industryValues.containsKey(valueType)) {
            Map<String, List<String>> typeValues = industryValues.get(valueType);
            
            if (typeValues.containsKey(industry)) {
                return typeValues.get(industry);
            }
        }
        
        // Default list if specific industry or value type not found
        return new List<String>{'Item 1', 'Item 2', 'Item 3'};
    }
    
    /**
     * Format a value based on region and format type
     * @param value The value to format
     * @param formatType The type of formatting to apply (phone, currency, companyName, etc.)
     * @param context The context map containing locale, region, etc.
     * @return The formatted value
     */
    public static String getRegionalFormat(String value, String formatType, Map<String, Object> context) {
        if (value == null || formatType == null) {
            return value;
        }
        
        String locale = (String)context.get('locale');
        String region = (String)context.get('region');
        
        if (formatType.equals('phone')) {
            return formatPhoneNumber(value, locale, region);
        } else if (formatType.equals('currency')) {
            return formatCurrency(value, locale, region);
        } else if (formatType.equals('companyName')) {
            return formatCompanyName(value, locale, region);
        } else {
            return value;
        }
    }
    
    /**
     * Format a company name based on locale and region
     * @param name The base company name
     * @param locale The locale
     * @param region The region
     * @return The formatted company name
     */
    private static String formatCompanyName(String name, String locale, String region) {
        if (name == null) {
            return null;
        }
        
        if (locale == null) {
            return name;
        }
        
        // Format based on locale
        if (locale.startsWith('fr')) {
            return name + ' S.A.R.L.';
        } else if (locale.startsWith('de')) {
            return name + ' GmbH';
        } else if (locale.startsWith('es')) {
            return name + ' S.A.';
        } else if (locale.startsWith('it')) {
            return name + ' S.p.A.';
        } else if (locale.startsWith('ja')) {
            return name + ' KK';
        } else if (locale.startsWith('zh_CN')) {
            return name + ' 有限公司';
        } else if (locale.startsWith('nl')) {
            return name + ' B.V.';
        } else if (locale.startsWith('pt')) {
            return name + ' Ltda.';
        } else if (locale.startsWith('en_GB')) {
            return name + ' Ltd.';
        } else {
            // Default to Inc. for US and other unspecified locales
            return name + ' Inc.';
        }
    }
    
    /**
     * Format a phone number based on region
     * @param phoneNumber The phone number to format
     * @param locale The locale
     * @param region The region
     * @return The formatted phone number
     */
    private static String formatPhoneNumber(String phoneNumber, String locale, String region) {
        if (phoneNumber == null) {
            return null;
        }
        
        if (region == null) {
            return phoneNumber;
        }
        
        // Simple region-based phone formatting
        if (region.equals('North America')) {
            // Format: (123) 456-7890
            if (phoneNumber.length() == 10) {
                return '(' + phoneNumber.substring(0, 3) + ') ' + 
                       phoneNumber.substring(3, 6) + '-' + 
                       phoneNumber.substring(6);
            }
        } else if (region.equals('Europe')) {
            // Format: +44 12 3456 7890 (example for UK)
            if (phoneNumber.length() >= 10) {
                String countryCode = locale.startsWith('fr') ? '+33' : 
                                    locale.startsWith('de') ? '+49' : 
                                    locale.startsWith('it') ? '+39' : 
                                    locale.startsWith('es') ? '+34' : '+44';
                return countryCode + ' ' + phoneNumber.substring(0, 2) + ' ' + 
                       phoneNumber.substring(2, 6) + ' ' + 
                       phoneNumber.substring(6);
            }
        }
        
        // Default: return as is if no formatting rules apply
        return phoneNumber;
    }
    
    /**
     * Format a currency value based on locale
     * @param value The currency value to format
     * @param locale The locale
     * @param region The region
     * @return The formatted currency value
     */
    private static String formatCurrency(String value, String locale, String region) {
        if (value == null) {
            return null;
        }
        
        if (locale == null) {
            return value;
        }
        
        // Simple currency formatting
        if (locale.startsWith('en_US')) {
            return '$' + value;
        } else if (locale.startsWith('en_GB')) {
            return '£' + value;
        } else if (locale.startsWith('fr') || locale.startsWith('de') || locale.startsWith('it') || locale.startsWith('es')) {
            // European format with Euro
            return value + ' €';
        } else if (locale.startsWith('ja')) {
            return '¥' + value;
        } else {
            return '$' + value; // Default to USD
        }
    }
}