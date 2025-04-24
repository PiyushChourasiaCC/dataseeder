/**
 * Test class for LLMService
 * 
 * Provides test coverage for LLM API integration
 */
@isTest
public class LLMServiceTest {
    
    // Mock HTTP callout
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        
        public MockHttpResponseGenerator(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            // Create a mock response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            res.setStatusCode(statusCode);
            return res;
        }
    }
    
    /**
     * Test successful text generation
     */
    @isTest
    static void testGenerateTextSuccess() {
        // Mock response
        String mockResponseBody = '{"id":"chatcmpl-123","object":"chat.completion","created":1677858242,"model":"gpt-3.5-turbo-0613","usage":{"prompt_tokens":13,"completion_tokens":7,"total_tokens":20},"choices":[{"message":{"role":"assistant","content":"This is a test response"},"finish_reason":"stop","index":0}]}';
        
        // Set the mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, mockResponseBody));
        
        // Context for the generation
        Map<String, Object> context = new Map<String, Object>{
            'locale' => 'en_US',
            'industry' => 'Technology'
        };
        
        // Call the method
        Test.startTest();
        String result;
        try {
            result = LLMService.generateText('Sample prompt', context);
        } catch (Exception e) {
            // This should not happen in the success case
            System.assert(false, 'Exception thrown in success case: ' + e.getMessage());
        }
        Test.stopTest();
        
        // Verify result
        System.assertEquals('This is a test response', result, 'Generated text should match mock response');
    }
    
    /**
     * Test error response from API
     */
    @isTest
    static void testGenerateTextError() {
        // Mock error response
        String mockResponseBody = '{"error":{"message":"Invalid API key","type":"invalid_request_error","param":null,"code":null}}';
        
        // Set the mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(401, mockResponseBody));
        
        // Context for the generation
        Map<String, Object> context = new Map<String, Object>{
            'locale' => 'en_US',
            'industry' => 'Technology'
        };
        
        // Call the method
        Test.startTest();
        try {
            String result = LLMService.generateText('Sample prompt', context);
            // This should not happen in the error case
            System.assert(false, 'Exception not thrown in error case');
        } catch (LLMService.LLMServiceException e) {
            // Expected exception
            System.assert(e.getMessage().contains('Error from OpenAI API'), 'Exception message should mention API error');
        }
        Test.stopTest();
    }
    
    /**
     * Test field value generation
     */
    @isTest
    static void testGenerateFieldValues() {
        // Mock response with field values
        String mockResponseBody = '{"id":"chatcmpl-123","object":"chat.completion","created":1677858242,"model":"gpt-3.5-turbo-0613","usage":{"prompt_tokens":13,"completion_tokens":7,"total_tokens":20},"choices":[{"message":{"role":"assistant","content":"{\\"Name\\":\\"Acme Corporation\\",\\"Industry\\":\\"Technology\\",\\"Phone\\":\\"+1 555-123-4567\\"}"},"finish_reason":"stop","index":0}]}';
        
        // Set the mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, mockResponseBody));
        
        // Context for the generation
        Map<String, Object> context = new Map<String, Object>{
            'locale' => 'en_US',
            'industry' => 'Technology'
        };
        
        // List of field configurations
        List<Map<String, Object>> fields = new List<Map<String, Object>>{
            new Map<String, Object>{'name' => 'Name', 'type' => 'String', 'object' => 'Account'},
            new Map<String, Object>{'name' => 'Industry', 'type' => 'Picklist', 'object' => 'Account'},
            new Map<String, Object>{'name' => 'Phone', 'type' => 'Phone', 'object' => 'Account'}
        };
        
        // Call the method
        Test.startTest();
        Map<String, Object> result = LLMService.generateFieldValues('Account', fields, context);
        Test.stopTest();
        
        // Verify result
        System.assertEquals('Acme Corporation', result.get('Name'), 'Name should match mock response');
        System.assertEquals('Technology', result.get('Industry'), 'Industry should match mock response');
        System.assertEquals('+1 555-123-4567', result.get('Phone'), 'Phone should match mock response');
    }
    
    /**
     * Test field value generation with parsing error
     */
    @isTest
    static void testGenerateFieldValuesParsingError() {
        // Mock response with invalid JSON
        String mockResponseBody = '{"id":"chatcmpl-123","object":"chat.completion","created":1677858242,"model":"gpt-3.5-turbo-0613","usage":{"prompt_tokens":13,"completion_tokens":7,"total_tokens":20},"choices":[{"message":{"role":"assistant","content":"This is not valid JSON"},"finish_reason":"stop","index":0}]}';
        
        // Set the mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, mockResponseBody));
        
        // Context for the generation
        Map<String, Object> context = new Map<String, Object>{
            'locale' => 'en_US',
            'industry' => 'Technology'
        };
        
        // List of field configurations
        List<Map<String, Object>> fields = new List<Map<String, Object>>{
            new Map<String, Object>{'name' => 'Name', 'type' => 'String', 'object' => 'Account'}
        };
        
        // Call the method
        Test.startTest();
        Map<String, Object> result = LLMService.generateFieldValues('Account', fields, context);
        Test.stopTest();
        
        // Verify result
        System.assertEquals(0, result.size(), 'Result should be empty when parsing fails');
    }
    
    /**
     * Test invalid response format
     */
    @isTest
    static void testInvalidResponseFormat() {
        // Mock response with missing choices
        String mockResponseBody = '{"id":"chatcmpl-123","object":"chat.completion","created":1677858242,"model":"gpt-3.5-turbo-0613"}';
        
        // Set the mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, mockResponseBody));
        
        // Context for the generation
        Map<String, Object> context = new Map<String, Object>{
            'locale' => 'en_US',
            'industry' => 'Technology'
        };
        
        // Call the method
        Test.startTest();
        try {
            String result = LLMService.generateText('Sample prompt', context);
            // This should not happen in the error case
            System.assert(false, 'Exception not thrown for invalid response format');
        } catch (LLMService.LLMServiceException e) {
            // Expected exception
            System.assert(e.getMessage().contains('Unable to parse response'), 'Exception message should mention parsing error');
        }
        Test.stopTest();
    }
} 