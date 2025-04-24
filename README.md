# DataSeeder for Salesforce

DataSeeder is a powerful application for generating realistic test data directly within Salesforce.

## Features

- Create and manage data generation templates
- Select Salesforce objects and fields for data generation
- Configure contextual parameters like locale, industry, and region
- Preview generated data before insertion
- Insert data with proper transaction handling and relationship mapping
- Import/export templates for sharing

## Components

- **Apex Classes**: Backend services for data generation, insertion, and template management
- **Custom Objects**: DataSeederTemplate__c to store template configurations
- **Custom Metadata**: DataSeederConfig__mdt for application configuration
- **Lightning Web Components**: Modern UI for configuring and generating data
- **Permission Sets**: DataSeederAdmin and DataSeederUser for access control

## Getting Started

1. Deploy the application to your Salesforce org
2. Assign the appropriate permission set to your users
3. Configure your OpenAI API key in the LLM API Named Credential
4. Navigate to the DataSeeder tab and start creating templates

## Configuration

The application can be configured via custom metadata:

- `MaxTotalRecords`: Maximum number of total records (default: 50)
- `MaxFieldsPerObject`: Maximum fields per object (default: 15)
- `MaxBatchSize`: DML batch size for governor limits (default: 10)

## Development

This project is built using Salesforce DX. For local development:

```sh
git clone https://github.com/your-org/dataseeder.git
cd dataseeder
sfdx force:source:push -u your-org
```

## Testing

All Apex classes have corresponding test classes with >75% code coverage.

To run tests:

```sh
sfdx force:apex:test:run -u your-org
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. 