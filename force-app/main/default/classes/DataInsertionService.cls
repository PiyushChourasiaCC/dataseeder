/**
 * DataInsertionService
 * 
 * Responsible for inserting generated Salesforce data with proper transaction management and error handling.
 * Handles hierarchical insertions and rollbacks for data integrity.
 */
public without sharing class DataInsertionService {
    
    // Maximum batch size for DML operations (to respect governor limits)
    private static final Integer MAX_BATCH_SIZE = 10;
    
    // Custom log object (could be expanded to a custom object or platform event)
    private static List<ErrorLog> errorLogs = new List<ErrorLog>();
    
    /**
     * Internal method for inserting records - can be called from other Apex classes
     * 
     * @param records Map of SObject API names to lists of records to insert
     * @return Map<String, Object> Result information with success, record IDs, and errors
     */
    public static Map<String, Object> insertRecordsInternal(Map<String, List<SObject>> records) {
        // Create a savepoint for rollback if needed
        Savepoint sp = Database.setSavepoint();
        
        Map<String, List<Id>> insertedRecordIds = new Map<String, List<Id>>();
        List<String> errors = new List<String>();
        Boolean success = true;
        
        try {
            // Validate input
            if (records == null || records.isEmpty()) {
                throw new DataInsertionException('No records provided for insertion');
            }
            
            // Sort objects by dependency (parent objects first)
            List<String> insertOrder = determineInsertionOrder(records);
            
            // Insert records in order
            for (String objectName : insertOrder) {
                if (records.containsKey(objectName)) {
                    List<SObject> objectRecords = records.get(objectName);
                    
                    // Skip if no records or empty list
                    if (objectRecords == null || objectRecords.isEmpty()) {
                        System.debug(LoggingLevel.INFO, 'No records to insert for object: ' + objectName);
                        continue;
                    }
                    
                    // Verify access to object
                    Schema.DescribeSObjectResult objDescribe = 
                        Schema.getGlobalDescribe().get(objectName).getDescribe();
                    
                    if (!objDescribe.isCreateable()) {
                        String errorMessage = 'You do not have permission to create ' + objectName + ' records';
                        errors.add(errorMessage);
                        System.debug(LoggingLevel.ERROR, errorMessage);
                        success = false;
                        continue;
                    }
                    
                    List<Id> objectIds = new List<Id>();
                    
                    // Insert in batches to respect governor limits
                    for (Integer i = 0; i < objectRecords.size(); i += MAX_BATCH_SIZE) {
                        Integer endIndex = Math.min(i + MAX_BATCH_SIZE, objectRecords.size());
                        List<SObject> batch = new List<SObject>();
                        for (Integer j = i; j < endIndex; j++) {
                            batch.add(objectRecords[j]);
                        }
                        
                        // Insert with partial success option to capture per-record errors
                        Database.SaveResult[] results = Database.insert(batch, false);
                        
                        // Process results
                        for (Integer j = 0; j < results.size(); j++) {
                            Database.SaveResult result = results[j];
                            if (result.isSuccess()) {
                                objectIds.add(result.getId());
                            } else {
                                // Log errors
                                for (Database.Error err : result.getErrors()) {
                                    String errorMessage = 'Error on ' + objectName + ' record ' + j + ': ' + 
                                                         err.getStatusCode() + ' - ' + err.getMessage();
                                    errors.add(errorMessage);
                                    addErrorLog(objectName, batch[j], errorMessage);
                                }
                                success = false;
                            }
                        }
                    }
                    
                    insertedRecordIds.put(objectName, objectIds);
                }
            }
            
            // If any errors occurred, roll back the transaction
            if (!success) {
                Database.rollback(sp);
                insertedRecordIds.clear();
            }
        } catch (Exception e) {
            // Handle unexpected exceptions
            success = false;
            String errorMessage = 'Unexpected error: ' + e.getMessage() + ' - ' + e.getStackTraceString();
            errors.add(errorMessage);
            System.debug(LoggingLevel.ERROR, errorMessage);
            Database.rollback(sp);
            insertedRecordIds.clear();
        }
        
        // Create and return result as a map
        Map<String, Object> result = new Map<String, Object>{
            'success' => success,
            'insertedRecordIds' => insertedRecordIds,
            'errors' => errors
        };
        
        return result;
    }
    
    /**
     * Insert records with transaction management
     * 
     * @param records Map of SObject API names to lists of records to insert
     * @return DataInsertionResult Object containing insertion results and errors
     */
    @AuraEnabled
    public static DataInsertionResult insertRecords(Map<String, List<SObject>> records) {
        Map<String, Object> result = insertRecordsInternal(records);
        
        // Convert to DataInsertionResult type
        DataInsertionResult insertionResult = new DataInsertionResult();
        insertionResult.success = (Boolean)result.get('success');
        insertionResult.insertedRecordIds = (Map<String, List<Id>>)result.get('insertedRecordIds');
        insertionResult.errors = (List<String>)result.get('errors');
        
        return insertionResult;
    }
    
    /**
     * Insert records from JSON string
     * 
     * @param recordsJson JSON string containing records to insert
     * @return DataInsertionResult Object containing insertion results and errors
     */
    @AuraEnabled
    public static DataInsertionResult insertRecordsFromJson(String recordsJson) {
        try {
            // Deserialize the JSON string to a map of objects
            Map<String, Object> recordsMap = (Map<String, Object>) JSON.deserializeUntyped(recordsJson);
            
            // Convert to appropriate SObject types
            Map<String, List<SObject>> typedRecords = new Map<String, List<SObject>>();
            
            for (String objectName : recordsMap.keySet()) {
                Object recordsObj = recordsMap.get(objectName);
                if (recordsObj instanceof List<Object>) {
                    List<Object> recordsList = (List<Object>) recordsObj;
                    List<SObject> typedList = new List<SObject>();
                    
                    for (Object recordObj : recordsList) {
                        if (recordObj instanceof Map<String, Object>) {
                            Map<String, Object> recordMap = (Map<String, Object>) recordObj;
                            
                            // Get SObject type from attributes
                            String sobjectType = objectName;
                            if (recordMap.containsKey('attributes') && recordMap.get('attributes') instanceof Map<String, Object>) {
                                Map<String, Object> attributes = (Map<String, Object>) recordMap.get('attributes');
                                if (attributes.containsKey('type')) {
                                    sobjectType = (String) attributes.get('type');
                                }
                            }
                            
                            // Create SObject with the right type
                            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(sobjectType);
                            if (targetType == null) {
                                throw new DataInsertionException('Invalid SObject type: ' + sobjectType);
                            }
                            
                            SObject sobj = targetType.newSObject();
                            
                            // Copy fields (excluding attributes)
                            for (String fieldName : recordMap.keySet()) {
                                if (fieldName != 'attributes') {
                                    sobj.put(fieldName, recordMap.get(fieldName));
                                }
                            }
                            
                            typedList.add(sobj);
                        }
                    }
                    
                    if (!typedList.isEmpty()) {
                        typedRecords.put(objectName, typedList);
                    }
                }
            }
            
            // Now call the regular insertRecords method
            return insertRecords(typedRecords);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error deserializing records JSON: ' + e.getMessage() + '\n' + e.getStackTraceString());
            DataInsertionResult result = new DataInsertionResult();
            result.success = false;
            result.errors.add('Error processing records: ' + e.getMessage());
            return result;
        }
    }
    
    /**
     * Determine proper insertion order based on relationships
     * 
     * @param records Map of SObject API names to lists of records
     * @return List<String> Ordered list of object API names
     */
    private static List<String> determineInsertionOrder(Map<String, List<SObject>> records) {
        // Simple implementation - in a real app, this would analyze actual dependencies
        // Standard objects typically come before custom objects
        List<String> standardObjects = new List<String>{'Account', 'Contact', 'Opportunity', 'Lead', 'Case'};
        List<String> allObjects = new List<String>(records.keySet());
        List<String> result = new List<String>();
        
        // Add standard objects first (if they exist in our records)
        for (String stdObj : standardObjects) {
            if (allObjects.contains(stdObj)) {
                result.add(stdObj);
            }
        }
        
        // Add remaining objects
        for (String obj : allObjects) {
            if (!result.contains(obj)) {
                result.add(obj);
            }
        }
        
        return result;
    }
    
    /**
     * Add an error log entry
     * 
     * @param objectName API name of the SObject
     * @param record The record that caused the error
     * @param errorMessage The error message
     */
    private static void addErrorLog(String objectName, SObject record, String errorMessage) {
        ErrorLog log = new ErrorLog();
        log.timestamp = System.now();
        log.objectName = objectName;
        log.recordJson = JSON.serialize(record);
        log.errorMessage = errorMessage;
        
        errorLogs.add(log);
        
        // In a real implementation, log to a custom object or platform event
        System.debug(LoggingLevel.ERROR, log);
    }
    
    /**
     * Error log structure
     */
    private class ErrorLog {
        public DateTime timestamp;
        public String objectName;
        public String recordJson;
        public String errorMessage;
        
        public override String toString() {
            return 'ERROR [' + timestamp + '] ' + objectName + ': ' + errorMessage + '\nRecord: ' + recordJson;
        }
    }
    
    /**
     * Class to represent insertion results
     */
    public class DataInsertionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Map<String, List<Id>> insertedRecordIds;
        @AuraEnabled public List<String> errors;
        
        public DataInsertionResult() {
            success = true;
            insertedRecordIds = new Map<String, List<Id>>();
            errors = new List<String>();
        }
    }
    
    /**
     * Asynchronously insert records (for situations that need to avoid governor limits)
     * 
     * @param records Map of SObject API names to lists of records to insert
     */
    @future
    public static void insertRecordsAsync(String recordsJson) {
        try {
            // Deserialize records from JSON
            Map<String, List<SObject>> records = 
                (Map<String, List<SObject>>) JSON.deserialize(recordsJson, Map<String, List<SObject>>.class);
            
            // Insert records
            insertRecords(records);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in async insertion: ' + e.getMessage() + ' - ' + e.getStackTraceString());
        }
    }
    
    /**
     * Custom exception class for data insertion errors
     */
    public class DataInsertionException extends Exception {}
} 