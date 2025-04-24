/**
 * LLMService
 * 
 * Service class for making callouts to OpenAI API via the LLMAPI named credential
 * Used by DataGenerationService to generate realistic data values
 */
public without sharing class LLMService {
    
    // Named credential for OpenAI API
    private static final String NAMED_CREDENTIAL = 'callout:LLMAPI';
    
    // OpenAI API endpoint for completions
    private static final String COMPLETION_ENDPOINT = '/chat/completions';
    
    // Model to use
    private static final String DEFAULT_MODEL = 'gpt-3.5-turbo';
    
    // Whether to use a mock response for testing in non-test contexts (useful in sandboxes/dev orgs)
    private static final Boolean USE_MOCK_IN_DEV = false;
    
    /**
     * Generate text completion using OpenAI API
     * 
     * @param prompt The prompt to send to the API
     * @param context Map of context variables to include in the system message
     * @return String The generated text response
     */
    public static String generateText(String prompt, Map<String, Object> context) {
        try {
            // In a test context, allow the test to provide mock responses
            if (Test.isRunningTest()) {
                return null; // Mock responses are set up in test classes
            }
            
            // For non-test contexts that still need mock data
            if (USE_MOCK_IN_DEV && !Test.isRunningTest()) {
                return getMockResponse(prompt);
            }
            
            HttpRequest req = buildRequest(prompt, context);
            Http http = new Http();
            
            // Make callout
            HttpResponse res = http.send(req);
            
            // Check response
            if (res.getStatusCode() == 200) {
                String responseBody = res.getBody();
                System.debug(LoggingLevel.INFO, 'API Response: ' + responseBody.left(200) + '...');
                return parseResponse(responseBody);
            } else {
                System.debug(LoggingLevel.ERROR, 'Error from OpenAI API: ' + res.getBody());
                throw new LLMServiceException('Error from OpenAI API: Status ' + res.getStatusCode() + ' - ' + res.getStatus());
            }
        } catch (LLMServiceException e) {
            throw e; // Re-throw custom exceptions
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error calling OpenAI API: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new LLMServiceException('Error calling OpenAI API: ' + e.getMessage());
        }
    }
    
    /**
     * Generate field values for an object
     * 
     * @param objectName API name of the SObject
     * @param fields List of field configurations
     * @param context Context parameters
     * @return Map<String, Object> Map of field names to generated values
     */
    public static Map<String, Object> generateFieldValues(String objectName, List<Map<String, Object>> fields, Map<String, Object> context) {
        try {
            // In test context or dev mode with mocks, return a predefined set of field values
            if (Test.isRunningTest() || (USE_MOCK_IN_DEV && !Test.isRunningTest())) {
                return getMockFieldValues(fields);
            }
            
            String fieldJson = JSON.serialize(fields);
            String contextJson = JSON.serialize(context);
            
            String prompt = buildFieldValuesPrompt(objectName, fieldJson, contextJson);
            String response = generateText(prompt, context);
            
            // Guard against null responses
            if (String.isBlank(response)) {
                System.debug(LoggingLevel.WARN, 'Empty response from LLM API');
                return new Map<String, Object>();
            }
            
            try {
                // Parse the response - should be a JSON object with field names as keys
                Map<String, Object> fieldValues = (Map<String, Object>) JSON.deserializeUntyped(response);
                
                // Validate the values to ensure they're compatible with field types
                Map<String, Object> validatedValues = new Map<String, Object>();
                for (Map<String, Object> field : fields) {
                    String fieldName = (String) field.get('name');
                    String fieldType = (String) field.get('type');
                    
                    if (fieldValues.containsKey(fieldName)) {
                        Object value = fieldValues.get(fieldName);
                        validatedValues.put(fieldName, value);
                    }
                }
                
                return validatedValues;
            } catch (JSONException e) {
                System.debug(LoggingLevel.ERROR, 'JSON parsing error for response: ' + response);
                System.debug(LoggingLevel.ERROR, 'Error details: ' + e.getMessage());
                // Try to extract JSON using regex if JSON is embedded in other text
                return extractJsonFromText(response);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error parsing field values response: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Response was: ' + response);
                // Fallback to default values
                return new Map<String, Object>();
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error generating field values: ' + e.getMessage());
            return new Map<String, Object>();
        }
    }
    
    /**
     * Attempt to extract JSON object from a text response that might have additional content
     */
    private static Map<String, Object> extractJsonFromText(String text) {
        try {
            // Pattern to match JSON object with opening and closing braces
            Pattern p = Pattern.compile('\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}');
            Matcher m = p.matcher(text);
            
            if (m.find()) {
                String jsonPart = m.group(0);
                return (Map<String, Object>) JSON.deserializeUntyped(jsonPart);
            }
            
            return new Map<String, Object>();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error extracting JSON from text: ' + e.getMessage());
            return new Map<String, Object>();
        }
    }
    
    /**
     * Build the HTTP request for the OpenAI API
     * 
     * @param prompt The user prompt
     * @param context Context parameters
     * @return HttpRequest The configured request
     */
    private static HttpRequest buildRequest(String prompt, Map<String, Object> context) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + COMPLETION_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        
        // Build system message with context
        String systemMessage = 'You are a data generation assistant that creates realistic and highly diverse sample data for Salesforce. ' +
                              'You should respond with valid values in the requested format. ' +
                              'IMPORTANT: Generate truly unique values for each field. Do not reuse values across multiple records. ' +
                              'Be creative and varied in your data generation, especially for company names, addresses, and contact information. ' +
                              'Use the following context parameters for relevance: ' + JSON.serialize(context);
        
        // Build messages array
        List<Map<String, String>> messages = new List<Map<String, String>>{
            new Map<String, String>{ 'role' => 'system', 'content' => systemMessage },
            new Map<String, String>{ 'role' => 'user', 'content' => prompt }
        };
        
        // Build request body
        Map<String, Object> requestBody = new Map<String, Object>{
            'model' => DEFAULT_MODEL,
            'messages' => messages,
            'temperature' => 0.9, // Increased for more randomness
            'max_tokens' => 500,
            'top_p' => 1.0,
            'frequency_penalty' => 0.5, // Added to reduce repetition
            'presence_penalty' => 0.5 // Added to encourage new content
        };
        
        req.setBody(JSON.serialize(requestBody));
        return req;
    }
    
    /**
     * Parse the response from the OpenAI API
     * 
     * @param responseBody The response body
     * @return String The extracted text from the response
     */
    private static String parseResponse(String responseBody) {
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            
            // Get the choices array
            List<Object> choices = (List<Object>) responseMap.get('choices');
            if (choices != null && !choices.isEmpty()) {
                Map<String, Object> choice = (Map<String, Object>) choices[0];
                Map<String, Object> message = (Map<String, Object>) choice.get('message');
                if (message != null) {
                    return (String) message.get('content');
                }
            }
            
            throw new LLMServiceException('Unable to parse response from OpenAI API');
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error parsing API response: ' + e.getMessage());
            throw new LLMServiceException('Error parsing API response: ' + e.getMessage());
        }
    }
    
    /**
     * Build prompt for generating field values
     * 
     * @param objectName API name of the SObject
     * @param fieldJson JSON string of field configurations
     * @param contextJson JSON string of context parameters
     * @return String The prompt for field value generation
     */
    private static String buildFieldValuesPrompt(String objectName, String fieldJson, String contextJson) {
        // Add a random seed to ensure unique values each time
        String randomSeed = String.valueOf(Datetime.now().getTime()) + '-' + Math.round(Math.random() * 10000);
        
        return 'Generate realistic values for the following Salesforce ' + objectName + ' fields:\n\n' +
               'Fields: ' + fieldJson + '\n\n' +
               'Context: ' + contextJson + '\n\n' +
               'Use this unique identifier to generate completely different values from previous calls: ' + randomSeed + '\n\n' +
               'Please respond with ONLY a JSON object where the keys are the field names and the values are appropriate ' +
               'for the field types, respecting any constraints and formatting requirements. ' +
               'Ensure values are appropriate for the industry, region, and locale provided in the context. ' +
               'Return ONLY the JSON with no additional explanations or wrappers.';
    }
    
    /**
     * Get mock response for testing in dev orgs
     */
    private static String getMockResponse(String prompt) {
        // If the prompt is asking for field values, return a mock field values JSON
        if (prompt.contains('Generate realistic values for')) {
            return '{"Name":"Acme Corporation","Industry":"Technology","Phone":"+1 555-123-4567"}';
        }
        
        // Default mock response
        return 'This is a mock response from the LLM service.';
    }
    
    /**
     * Get mock field values for testing
     */
    private static Map<String, Object> getMockFieldValues(List<Map<String, Object>> fields) {
        Map<String, Object> result = new Map<String, Object>();
        
        for (Map<String, Object> field : fields) {
            String fieldName = (String) field.get('name');
            String fieldType = (String) field.get('type');
            
            if (fieldName == 'Name') {
                result.put(fieldName, 'Mock Company ' + Math.round(Math.random() * 1000));
            } else if (fieldName == 'Industry') {
                result.put(fieldName, 'Technology');
            } else if (fieldName == 'Phone') {
                result.put(fieldName, '+1 555-' + Math.round(Math.random() * 999) + '-' + Math.round(Math.random() * 9999));
            } else if (fieldType == 'String') {
                result.put(fieldName, 'Mock ' + fieldName + ' ' + Math.round(Math.random() * 1000));
            } else if (fieldType == 'Number') {
                result.put(fieldName, Math.round(Math.random() * 100));
            } else if (fieldType == 'Boolean') {
                result.put(fieldName, Math.random() > 0.5);
            } else if (fieldType == 'Date') {
                result.put(fieldName, Date.today().addDays(Integer.valueOf(Math.random() * 30)));
            }
        }
        
        return result;
    }
    
    /**
     * Custom exception class
     */
    public class LLMServiceException extends Exception {}
} 