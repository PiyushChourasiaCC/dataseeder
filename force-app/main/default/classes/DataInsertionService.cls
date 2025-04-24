/**
 * DataInsertionService
 * 
 * Responsible for inserting generated Salesforce data with proper transaction management and error handling.
 * Handles hierarchical insertions and rollbacks for data integrity.
 */
public with sharing class DataInsertionService {
    
    // Maximum batch size for DML operations (to respect governor limits)
    private static final Integer MAX_BATCH_SIZE = 10;
    
    // Custom log object (could be expanded to a custom object or platform event)
    private static List<ErrorLog> errorLogs = new List<ErrorLog>();
    
    /**
     * Insert records with transaction management
     * 
     * @param records Map of SObject API names to lists of records to insert
     * @return DataInsertionResult Object containing insertion results and errors
     */
    @AuraEnabled
    public static DataInsertionResult insertRecords(Map<String, List<SObject>> records) {
        // Create a savepoint for rollback if needed
        Savepoint sp = Database.setSavepoint();
        
        Map<String, List<Id>> insertedRecordIds = new Map<String, List<Id>>();
        List<String> errors = new List<String>();
        Boolean success = true;
        
        try {
            // Sort objects by dependency (parent objects first)
            List<String> insertOrder = determineInsertionOrder(records);
            
            // Insert records in order
            for (String objectName : insertOrder) {
                if (records.containsKey(objectName)) {
                    List<SObject> objectRecords = records.get(objectName);
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
            errors.add('Unexpected error: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            Database.rollback(sp);
            insertedRecordIds.clear();
        }
        
        // Create and return result
        DataInsertionResult result = new DataInsertionResult();
        result.success = success;
        result.insertedRecordIds = insertedRecordIds;
        result.errors = errors;
        
        return result;
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
        public Boolean success;
        public Map<String, List<Id>> insertedRecordIds;
        public List<String> errors;
        
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
} 