/**
 * DataGenerationService
 * 
 * Responsible for generating sample Salesforce data based on configuration.
 * Handles parsing JSON configuration, calling LLM API, and creating SObject records.
 */
public without sharing class DataGenerationService {
    
    // Maximum number of fields allowed per object
    private static final Integer MAX_FIELDS_PER_OBJECT = 15;
    
    // Maximum relationship depth
    private static final Integer MAX_RELATIONSHIP_DEPTH = 3;
    
    // Maximum total records to generate
    private static final Integer MAX_TOTAL_RECORDS = 50;
    
    /**
     * Generate SObject records based on the provided configuration
     * 
     * @param configJson JSON configuration for data generation
     * @return Map<String, List<SObject>> Map of object API names to generated SObject records
     */
    @AuraEnabled
    public static Map<String, List<SObject>> generateData(String configJson) {
        try {
            System.debug(LoggingLevel.INFO, 'Generating data with config: ' + configJson);
            
            // Parse the configuration
            Map<String, Object> config = parseConfiguration(configJson);
            
            // Validate the configuration
            validateConfiguration(config);
            
            // Generate the data
            Map<String, List<SObject>> result = createSObjectRecords(config);
            
            // Debug the result
            System.debug(LoggingLevel.INFO, 'Generated data: ' + result);
            
            return result;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in generateData: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error generating data: ' + e.getMessage());
        }
    }
    
    /**
     * Parse the JSON configuration string into a map
     * 
     * @param configJson JSON configuration string
     * @return Map<String, Object> Parsed configuration
     */
    private static Map<String, Object> parseConfiguration(String configJson) {
        try {
            if (String.isBlank(configJson)) {
                throw new DataGenerationException('Configuration JSON is empty or null');
            }
            
            return (Map<String, Object>) JSON.deserializeUntyped(configJson);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error parsing JSON: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new DataGenerationException('Invalid JSON configuration: ' + e.getMessage());
        }
    }
    
    /**
     * Validate the configuration against Salesforce constraints
     * 
     * @param config Parsed configuration map
     */
    private static void validateConfiguration(Map<String, Object> config) {
        try {
            // Get the objects array
            List<Object> objects = (List<Object>) config.get('objects');
            
            if (objects == null || objects.isEmpty()) {
                throw new DataGenerationException('Configuration must include at least one object');
            }
            
            Integer totalRecords = 0;
            
            // Validate each object
            for (Object obj : objects) {
                Map<String, Object> objectConfig = (Map<String, Object>) obj;
                
                // Check if the object exists in Salesforce
                String objectName = (String) objectConfig.get('name');
                if (objectName == null || !validateSObjectExists(objectName)) {
                    throw new DataGenerationException('Invalid object name: ' + objectName);
                }
                
                // Validate fields
                List<Object> fields = (List<Object>) objectConfig.get('fields');
                if (fields == null || fields.isEmpty()) {
                    throw new DataGenerationException('Object ' + objectName + ' must have at least one field');
                }
                
                if (fields.size() > MAX_FIELDS_PER_OBJECT) {
                    throw new DataGenerationException('Object ' + objectName + ' exceeds maximum field limit of ' + MAX_FIELDS_PER_OBJECT);
                }
                
                // Validate relationship depth
                List<Object> relationships = (List<Object>) objectConfig.get('relationships');
                if (relationships != null) {
                    for (Object rel : relationships) {
                        Map<String, Object> relationship = (Map<String, Object>) rel;
                        if (!validateRelationship(relationship)) {
                            throw new DataGenerationException('Invalid relationship configuration');
                        }
                    }
                }
                
                // Track total record count
                Integer count = Integer.valueOf(objectConfig.get('count'));
                totalRecords += count;
            }
            
            // Check total record limit
            if (totalRecords > MAX_TOTAL_RECORDS) {
                throw new DataGenerationException('Total record count exceeds maximum limit of ' + MAX_TOTAL_RECORDS);
            }
        } catch (DataGenerationException e) {
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error validating configuration: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new DataGenerationException('Error validating configuration: ' + e.getMessage());
        }
    }
    
    /**
     * Validate that an SObject exists in the Salesforce org
     * 
     * @param objectName API name of the SObject
     * @return Boolean True if the object exists
     */
    private static Boolean validateSObjectExists(String objectName) {
        try {
            // Get the schema for the object
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            if (objectType == null) {
                System.debug(LoggingLevel.ERROR, 'Object does not exist: ' + objectName);
                return false;
            }
            
            // Verify the user has access to the object
            DescribeSObjectResult objDescribe = objectType.getDescribe();
            if (!objDescribe.isAccessible()) {
                System.debug(LoggingLevel.ERROR, 'Object is not accessible: ' + objectName);
                return false;
            }
            
            return true;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error validating SObject existence: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return false;
        }
    }
    
    /**
     * Validate a relationship configuration
     * 
     * @param relationship Relationship configuration
     * @return Boolean True if the relationship is valid
     */
    private static Boolean validateRelationship(Map<String, Object> relationship) {
        try {
            String childObject = (String) relationship.get('childObject');
            String parentObject = (String) relationship.get('parentObject');
            String field = (String) relationship.get('field');
            
            // Check that both objects exist
            if (!validateSObjectExists(childObject) || !validateSObjectExists(parentObject)) {
                return false;
            }
            
            // Check that the field exists on the child object
            Schema.SObjectType childType = Schema.getGlobalDescribe().get(childObject);
            Map<String, Schema.SObjectField> childFields = childType.getDescribe().fields.getMap();
            
            if (!childFields.containsKey(field)) {
                System.debug(LoggingLevel.ERROR, 'Field does not exist on child object: ' + field);
                return false;
            }
            
            // Check field accessibility
            Schema.DescribeFieldResult fieldDescribe = childFields.get(field).getDescribe();
            if (!fieldDescribe.isAccessible() || !fieldDescribe.isUpdateable()) {
                System.debug(LoggingLevel.ERROR, 'Field is not accessible or updateable: ' + field);
                return false;
            }
            
            return true;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error validating relationship: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return false;
        }
    }
    
    /**
     * Create SObject records based on the configuration
     * 
     * @param config Parsed configuration
     * @return Map<String, List<SObject>> Map of object API names to generated SObject records
     */
    private static Map<String, List<SObject>> createSObjectRecords(Map<String, Object> config) {
        Map<String, List<SObject>> records = new Map<String, List<SObject>>();
        
        try {
            // Get context parameters for LLM
            Map<String, Object> context = (Map<String, Object>) config.get('context');
            
            // Process each object
            List<Object> objects = (List<Object>) config.get('objects');
            for (Object obj : objects) {
                Map<String, Object> objectConfig = (Map<String, Object>) obj;
                String objectName = (String) objectConfig.get('name');
                Integer count = Integer.valueOf(objectConfig.get('count'));
                
                // Generate records for this object
                List<SObject> objectRecords = generateRecordsForObject(objectName, objectConfig, context, count);
                
                // Only add to the result if we have records
                if (objectRecords != null && !objectRecords.isEmpty()) {
                    records.put(objectName, objectRecords);
                }
            }
            
            // Process relationships after all records have been created
            if (!records.isEmpty()) {
                processRelationships(config, records);
            }
            
            return records;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating SObject records: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new DataGenerationException('Error creating SObject records: ' + e.getMessage());
        }
    }
    
    /**
     * Generate records for a specific object
     * 
     * @param objectName API name of the SObject
     * @param objectConfig Configuration for this object
     * @param context Context parameters for data generation
     * @param count Number of records to generate
     * @return List<SObject> Generated SObject records
     */
    private static List<SObject> generateRecordsForObject(String objectName, Map<String, Object> objectConfig, 
                                                  Map<String, Object> context, Integer count) {
        List<SObject> records = new List<SObject>();
        
        try {
            List<Object> fields = (List<Object>) objectConfig.get('fields');
            
            // Get SObject type
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);
            if (sObjType == null) {
                System.debug(LoggingLevel.ERROR, 'Object type not found: ' + objectName);
                return records;
            }
            
            // Verify field accessibility
            Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
            
            // Create the specified number of records
            for (Integer i = 0; i < count; i++) {
                SObject record = sObjType.newSObject();
                
                // Generate data for each field
                for (Object fieldObj : fields) {
                    Map<String, Object> fieldConfig = (Map<String, Object>) fieldObj;
                    String fieldName = (String) fieldConfig.get('name');
                    String fieldType = (String) fieldConfig.get('type');
                    
                    // Check if field exists and is accessible
                    if (!fieldMap.containsKey(fieldName)) {
                        System.debug(LoggingLevel.ERROR, 'Field does not exist: ' + fieldName);
                        continue;
                    }
                    
                    Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                    if (!fieldDescribe.isAccessible() || !fieldDescribe.isUpdateable()) {
                        System.debug(LoggingLevel.ERROR, 'Field is not accessible or updateable: ' + fieldName);
                        continue;
                    }
                    
                    // Generate appropriate data based on field type
                    Object fieldValue = generateFieldValue(fieldType, fieldConfig, context);
                    if (fieldValue != null) {
                        try {
                            record.put(fieldName, fieldValue);
                        } catch (Exception e) {
                            System.debug(LoggingLevel.ERROR, 'Error setting field value: ' + e.getMessage());
                        }
                    }
                }
                
                records.add(record);
            }
            
            return records;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error generating records for object: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return new List<SObject>();
        }
    }
    
    /**
     * Generate an appropriate value for a field based on its type
     * 
     * @param fieldType Salesforce field data type
     * @param fieldConfig Field configuration
     * @param context Context parameters for data generation
     * @return Object Generated field value
     */
    private static Object generateFieldValue(String fieldType, Map<String, Object> fieldConfig, Map<String, Object> context) {
        String fieldName = (String) fieldConfig.get('name');
        
        // Special handling for common required fields
        if (fieldName == 'Name') {
            // Generate more realistic names based on context
            String industry = context != null && context.containsKey('industry') 
                ? (String)context.get('industry') : 'General';
            String locale = context != null && context.containsKey('locale') 
                ? (String)context.get('locale') : 'en_US';
                
            return generateNameByContext(industry, locale) + ' ' + Math.round(Math.random() * 1000);
        }
        
        // For Phone fields, generate formatted phone numbers
        if (fieldName == 'Phone') {
            return '+' + (1 + Math.round(Math.random() * 98)) + ' ' + 
                   Math.round(Math.random() * 999) + '-' + 
                   Math.round(Math.random() * 999) + '-' + 
                   Math.round(Math.random() * 9999);
        }
        
        // For Industry field, use realistic values
        if (fieldName == 'Industry') {
            List<String> industries = new List<String>{
                'Agriculture', 'Apparel', 'Banking', 'Biotechnology', 'Chemicals',
                'Communications', 'Construction', 'Consulting', 'Education',
                'Electronics', 'Energy', 'Engineering', 'Entertainment', 'Environmental',
                'Finance', 'Food & Beverage', 'Government', 'Healthcare', 'Hospitality',
                'Insurance', 'Machinery', 'Manufacturing', 'Media', 'Not For Profit',
                'Recreation', 'Retail', 'Shipping', 'Technology', 'Telecommunications',
                'Transportation', 'Utilities'
            };
            
            // If context has a specific industry, prefer that one with 70% probability
            if (context != null && context.containsKey('industry')) {
                String contextIndustry = (String)context.get('industry');
                // Clean up industry name to match picklist values
                if (contextIndustry.contains('Financial') || contextIndustry.contains('Finance')) {
                    contextIndustry = 'Finance';
                }
                
                if (Math.random() < 0.7) {
                    return contextIndustry;
                }
            }
            
            Integer index = Math.round(Math.random() * (industries.size() - 1));
            return industries[index];
        }
        
        // General field type handling
        if (fieldType == 'String') {
            Integer length = fieldConfig.containsKey('length') ? Integer.valueOf(fieldConfig.get('length')) : 50;
            return 'Sample' + Math.round(Math.random() * 1000);
        } else if (fieldType == 'Number') {
            Double minValue = fieldConfig.containsKey('minValue') ? Double.valueOf(fieldConfig.get('minValue')) : 0;
            Double maxValue = fieldConfig.containsKey('maxValue') ? Double.valueOf(fieldConfig.get('maxValue')) : 100;
            return Integer.valueOf(minValue + Math.random() * (maxValue - minValue));
        } else if (fieldType == 'Boolean') {
            return Math.random() > 0.5;
        } else if (fieldType == 'Date') {
            return Date.today().addDays(Integer.valueOf(Math.random() * 30));
        } else if (fieldType == 'DateTime') {
            return DateTime.now().addHours(Integer.valueOf(Math.random() * 24));
        } else if (fieldType == 'Picklist') {
            List<Object> picklistValues = (List<Object>) fieldConfig.get('picklistValues');
            if (picklistValues != null && !picklistValues.isEmpty()) {
                Integer index = Integer.valueOf(Math.random() * picklistValues.size());
                return picklistValues[index];
            }
            return null;
        } else {
            return null;
        }
    }
    
    /**
     * Generate contextually relevant name based on industry and locale
     */
    private static String generateNameByContext(String industry, String locale) {
        // Default prefixes for company names
        List<String> prefixes = new List<String>{
            'Global', 'Advanced', 'Premium', 'Elite', 'Superior', 'Innovative', 
            'United', 'Strategic', 'Dynamic', 'Precision', 'Reliable', 'Integrated'
        };
        
        // Industry-specific suffixes
        Map<String, List<String>> industrySuffixes = new Map<String, List<String>>{
            'Financial Services' => new List<String>{'Bank', 'Financial', 'Capital', 'Investments', 'Wealth', 'Securities'},
            'Technology' => new List<String>{'Tech', 'Systems', 'Software', 'Networks', 'Solutions', 'Digital'},
            'Healthcare' => new List<String>{'Health', 'Medical', 'Care', 'Wellness', 'Therapeutic', 'Life Sciences'},
            'Manufacturing' => new List<String>{'Manufacturing', 'Industries', 'Products', 'Materials', 'Fabrication'},
            'Retail' => new List<String>{'Retail', 'Stores', 'Goods', 'Marketplace', 'Outlet', 'Emporium'},
            'Energy' => new List<String>{'Energy', 'Power', 'Utilities', 'Resources', 'Renewable'}
        };
        
        // Default suffixes if industry not found
        List<String> defaultSuffixes = new List<String>{
            'Corp', 'Inc', 'LLC', 'Group', 'Company', 'Enterprises', 'Partners', 'International'
        };
        
        // Get a random prefix
        Integer prefixIndex = Math.round(Math.random() * (prefixes.size() - 1));
        String prefix = prefixes[prefixIndex];
        
        // Get industry-specific or default suffix
        List<String> suffixes = industrySuffixes.containsKey(industry) ? 
                               industrySuffixes.get(industry) : defaultSuffixes;
        Integer suffixIndex = Math.round(Math.random() * (suffixes.size() - 1));
        String suffix = suffixes[suffixIndex];
        
        // Create a context map for ContextSettingsService
        Map<String, Object> context = new Map<String, Object>{
            'locale' => locale,
            'industry' => industry,
            'region' => getRegionFromLocale(locale)
        };
        
        String name = prefix + ' ' + suffix;
        
        // Use ContextSettingsService to format the name based on region
        return ContextSettingsService.getRegionalFormat(name, 'companyName', context);
    }
    
    /**
     * Helper method to determine region from locale
     */
    private static String getRegionFromLocale(String locale) {
        if (locale == null) {
            return 'North America';
        }
        
        if (locale.startsWith('en_US')) {
            return 'North America';
        } else if (locale.startsWith('en_GB') || locale.startsWith('fr') || locale.startsWith('de') || locale.startsWith('it') || locale.startsWith('es_ES')) {
            return 'Europe';
        } else if (locale.startsWith('ja') || locale.startsWith('zh') || locale.startsWith('ko')) {
            return 'Asia Pacific';
        } else if (locale.startsWith('es_MX') || locale.startsWith('pt_BR')) {
            return 'Latin America';
        } else if (locale.startsWith('ar') || locale.equals('de')) {
            return 'MEA';
        } else {
            return 'North America';
        }
    }
    
    /**
     * Process relationship configurations and link related records
     * 
     * @param config Complete configuration
     * @param records Map of generated records
     */
    private static void processRelationships(Map<String, Object> config, Map<String, List<SObject>> records) {
        List<Object> objects = (List<Object>) config.get('objects');
        
        for (Object obj : objects) {
            Map<String, Object> objectConfig = (Map<String, Object>) obj;
            List<Object> relationships = (List<Object>) objectConfig.get('relationships');
            
            if (relationships != null) {
                for (Object rel : relationships) {
                    Map<String, Object> relationship = (Map<String, Object>) rel;
                    String childObject = (String) relationship.get('childObject');
                    String parentObject = (String) relationship.get('parentObject');
                    String field = (String) relationship.get('field');
                    
                    // Only process if we have both parent and child records
                    if (records.containsKey(childObject) && records.containsKey(parentObject)) {
                        List<SObject> childRecords = records.get(childObject);
                        List<SObject> parentRecords = records.get(parentObject);
                        
                        // Link each child to a random parent
                        for (SObject child : childRecords) {
                            if (!parentRecords.isEmpty()) {
                                Integer parentIndex = Integer.valueOf(Math.random() * parentRecords.size());
                                child.put(field, parentRecords[parentIndex].Id);
                            }
                        }
                    }
                }
            }
        }
    }
    
    /**
     * Custom exception class for data generation errors
     */
    public class DataGenerationException extends Exception {}
} 