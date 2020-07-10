# Prerequisites:
#  - Subscription to Google Cloud Platform.
#  - G Suite Super Admin account to set up a service account on the G Suite tenant.
#  - gcloud cli tool installed https://cloud.google.com/sdk/docs/downloads-versioned-archives


echo Step 1: Setup gcloud console project.
gcloud init

read -p "What is the project ID just created? " projectName

echo "Step 2: Enable APIs for Service Account"
gcloud services enable admin.googleapis.com drive.googleapis.com caldav.googleapis.com calendar-json.googleapis.com gmail.googleapis.com --project $projectName --quiet

echo "Step 3: Create Customer Tenant Service Account"
gcloud iam service-accounts create data-migration --description "data-migration" --display-name "data-migration" --project $projectName
echo "find the service email account"
serviceEmail="$(gcloud iam service-accounts list --format="value(EMAIL)" --filter="displayName:data-migration" --project $projectName)"
echo "Create the JSON Key."
gcloud iam service-accounts keys create ~/$serviceEmail-key.json --iam-account $serviceEmail
echo "Step 4: Setting the Scopes for the migration"
echo "Find the Unique ID field for that service account and copy the ID number"
uniqueId="$(gcloud iam service-accounts describe $serviceEmail --format="value(uniqueId)" --project $projectName)" 
echo "----------------"
echo "Action required: "
echo Go to https://admin.google.com and click on Security > Advanced Settings > Manage API Client Access.
echo In the Client ID field, paste in: $uniqueId 
echo In the One or More API Scopes field, paste all scopes listed below:
echo https://mail.google.com/, https://www.google.com/m8/feeds, https://www.googleapis.com/auth/contacts.readonly, https://www.googleapis.com/auth/calendar, https://www.googleapis.com/auth/admin.directory.group, https://www.googleapis.com/auth/admin.directory.user, https://www.googleapis.com/auth/drive, https://sites.google.com/feeds/, https://www.googleapis.com/auth/gmail.settings.sharing, https://www.googleapis.com/auth/gmail.settings.basic
echo Click Authorize.

read -p 'Ready to continue?'
echo "Go to your CloudMigrator or [MigrationWiz](https://migrationwiz.bittitan.com/app/projects) project and add ~/`$serviceEmail`-key.json to G Suite source/destination endpoint."