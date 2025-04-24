/**
 * @description Utility class for the DataSeeder application
 * @author Claude AI
 * @date 2023-09-13
 */
public with sharing class DataSeederUtility {
    
    /**
     * @description Validates field values against their respective field types
     * @param objectName The API name of the SObject
     * @param fieldMap Map of field API names to their values
     * @return Map<String, String> Map of field API names to error messages, empty if no errors
     */
    public static Map<String, String> validateFieldValues(String objectName, Map<String, Object> fieldMap) {
        Map<String, String> errorMap = new Map<String, String>();
        
        try {
            // Get the SObject describe result
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap2 = objDescribe.fields.getMap();
            
            // Validate each field value against its type
            for (String fieldName : fieldMap.keySet()) {
                if (fieldMap2.containsKey(fieldName)) {
                    Schema.DescribeFieldResult fieldDescribe = fieldMap2.get(fieldName).getDescribe();
                    Schema.DisplayType fieldType = fieldDescribe.getType();
                    Object fieldValue = fieldMap.get(fieldName);
                    
                    // Skip null values
                    if (fieldValue == null) continue;
                    
                    // Validate based on field type
                    String error = validateValueForFieldType(fieldValue, fieldType, fieldDescribe);
                    if (String.isNotBlank(error)) {
                        errorMap.put(fieldName, error);
                    }
                }
            }
        } catch (Exception e) {
            errorMap.put('SYSTEM_ERROR', 'Error during validation: ' + e.getMessage());
        }
        
        return errorMap;
    }
    
    /**
     * @description Validates a single value against a specific field type
     * @param value The value to validate
     * @param fieldType The Schema.DisplayType of the field
     * @param fieldDescribe The field describe result for additional validation details
     * @return String Error message if validation fails, null otherwise
     */
    private static String validateValueForFieldType(Object value, Schema.DisplayType fieldType, Schema.DescribeFieldResult fieldDescribe) {
        try {
            switch on fieldType {
                when STRING, TEXTAREA {
                    String strValue = String.valueOf(value);
                    Integer maxLength = fieldDescribe.getLength();
                    if (strValue.length() > maxLength) {
                        return 'Value exceeds maximum length of ' + maxLength;
                    }
                }
                when INTEGER {
                    Integer.valueOf(value);
                }
                when DOUBLE, CURRENCY, PERCENT {
                    Decimal.valueOf(String.valueOf(value));
                }
                when DATE {
                    if (value instanceof String) {
                        Date.valueOf((String)value);
                    } else if (!(value instanceof Date)) {
                        return 'Value is not a valid date';
                    }
                }
                when DATETIME {
                    if (value instanceof String) {
                        Datetime.valueOf((String)value);
                    } else if (!(value instanceof Datetime)) {
                        return 'Value is not a valid datetime';
                    }
                }
                when BOOLEAN {
                    if (!(value instanceof Boolean)) {
                        Boolean.valueOf(String.valueOf(value));
                    }
                }
                when EMAIL {
                    String email = String.valueOf(value);
                    if (!Pattern.matches('^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$', email)) {
                        return 'Invalid email format';
                    }
                }
                when PHONE {
                    // Basic phone validation - could be enhanced
                    String phone = String.valueOf(value);
                    if (!Pattern.matches('^[0-9+\\-\\s().]{5,20}$', phone)) {
                        return 'Invalid phone format';
                    }
                }
                when URL {
                    String url = String.valueOf(value);
                    if (!Pattern.matches('^https?://[\\w.-]+(:\\d+)?(/[\\w.-]*)*$', url)) {
                        return 'Invalid URL format';
                    }
                }
                when else {
                    // For other types, we'll just ensure conversion doesn't throw an error
                    String.valueOf(value);
                }
            }
            return null; // No error
        } catch (Exception e) {
            return 'Invalid value for this field type: ' + e.getMessage();
        }
    }
    
    /**
     * @description Formats generated records for display
     * @param records List of SObjects to format
     * @return List<Map<String, Object>> Formatted records
     */
    public static List<Map<String, Object>> formatRecordsForDisplay(List<SObject> records) {
        List<Map<String, Object>> formattedRecords = new List<Map<String, Object>>();
        
        if (records == null || records.isEmpty()) {
            return formattedRecords;
        }
        
        // Get all fields from the first record to ensure consistent display
        Map<String, Object> firstRecord = records[0].getPopulatedFieldsAsMap();
        Set<String> allFields = firstRecord.keySet();
        
        for (SObject record : records) {
            Map<String, Object> recordMap = new Map<String, Object>();
            Map<String, Object> populatedFields = record.getPopulatedFieldsAsMap();
            
            // Add all fields from the standard set
            for (String field : allFields) {
                Object value = populatedFields.containsKey(field) ? populatedFields.get(field) : null;
                recordMap.put(field, value);
            }
            
            formattedRecords.add(recordMap);
        }
        
        return formattedRecords;
    }
    
    /**
     * @description Sanitizes data for insertion
     * @param objectName The API name of the SObject
     * @param records List of maps representing records to sanitize
     * @return List<Map<String, Object>> Sanitized records
     */
    public static List<Map<String, Object>> sanitizeRecordsForInsertion(String objectName, List<Map<String, Object>> records) {
        List<Map<String, Object>> sanitizedRecords = new List<Map<String, Object>>();
        
        try {
            // Get fields for the object
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
            
            for (Map<String, Object> record : records) {
                Map<String, Object> sanitizedRecord = new Map<String, Object>();
                
                for (String fieldName : record.keySet()) {
                    if (fieldMap.containsKey(fieldName)) {
                        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                        Object value = record.get(fieldName);
                        
                        // Skip null values and fields the user can't create
                        if (value == null || !fieldDescribe.isCreateable()) continue;
                        
                        // Convert value to appropriate type
                        Object convertedValue = convertToFieldType(value, fieldDescribe.getType());
                        if (convertedValue != null) {
                            sanitizedRecord.put(fieldName, convertedValue);
                        }
                    }
                }
                
                if (!sanitizedRecord.isEmpty()) {
                    sanitizedRecords.add(sanitizedRecord);
                }
            }
        } catch (Exception e) {
            System.debug('Error sanitizing records: ' + e.getMessage());
        }
        
        return sanitizedRecords;
    }
    
    /**
     * @description Converts a value to the appropriate type for a field
     * @param value The value to convert
     * @param fieldType The Schema.DisplayType of the field
     * @return Object The converted value
     */
    private static Object convertToFieldType(Object value, Schema.DisplayType fieldType) {
        if (value == null) return null;
        
        try {
            switch on fieldType {
                when STRING, TEXTAREA, ID, REFERENCE, PICKLIST, MULTIPICKLIST {
                    return String.valueOf(value);
                }
                when INTEGER {
                    return Integer.valueOf(String.valueOf(value));
                }
                when DOUBLE, CURRENCY, PERCENT {
                    return Decimal.valueOf(String.valueOf(value));
                }
                when DATE {
                    if (value instanceof String) {
                        return Date.valueOf((String)value);
                    } else if (value instanceof Date) {
                        return value;
                    }
                }
                when DATETIME {
                    if (value instanceof String) {
                        return Datetime.valueOf((String)value);
                    } else if (value instanceof Datetime) {
                        return value;
                    }
                }
                when BOOLEAN {
                    if (value instanceof Boolean) {
                        return value;
                    } else {
                        return Boolean.valueOf(String.valueOf(value));
                    }
                }
                when else {
                    return value;
                }
            }
        } catch (Exception e) {
            System.debug('Error converting value [' + value + '] to type ' + fieldType + ': ' + e.getMessage());
            return null;
        }
        
        return null;
    }
} 