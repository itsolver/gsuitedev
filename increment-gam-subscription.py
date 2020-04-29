# TO DO: create custom gam python modules: https://groups.google.com/d/topic/google-apps-manager/SF7WaRqKBIk

bashCommand = "export OAUTHFILE=oauth2.txt-itsolver.net; /Users/angusmclauchlan/bin/gam/gam update resoldsubscription thealternativeboard.com.au Google-Apps-Unlimited seats 32 32"
import subprocess
process = subprocess.run(bashCommand, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, check=True, text=True)
print (process.stdout, process.stderr)

if process.stderr: 
    print(process.stderr)
else:
    print(process.stdout)
