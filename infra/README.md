# HTTPS for the web app

1. Deploy the distribution (about 5 minutes):

       aws cloudformation deploy --stack-name fittrack-web \
         --template-file infra/web-cloudfront.yaml --region us-east-1

2. Read the URL:

       aws cloudformation describe-stacks --stack-name fittrack-web \
         --query "Stacks[0].Outputs[?OutputKey=='AppUrl'].OutputValue" --output text

3. Allow that origin for progress photos (backend repo):

       sam deploy --parameter-overrides AppOrigin=https://dXXXXXXXX.cloudfront.net

   Keep your other parameters, or add them to `samconfig.toml`.

4. Open the https URL on the iPhone, sign in, remove the old home-screen icon and add this one.
   The old icon is a different origin, so it keeps its own (empty) storage.

5. After each web deploy the old files can stay cached for a short time. `deploy.sh` uploads the entry files with
   `no-cache`, so a normal reload picks them up.

The bucket stays public website hosting for now. Locking it down (private bucket plus origin access control)
is a worthwhile follow-up but changes the bucket policy, so do it as its own step.
