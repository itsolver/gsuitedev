import subprocess
import argparse

parser = argparse.ArgumentParser(
    description='Process new quantity for G Suite subscription')
parser.add_argument('integers', metavar='quantity', type=int,
                    help='an integer for the g-suite new_quantity')
# parser.add_argument('customer', type=open,
#                     help='the primary domain of the resold customer in g-suite')
args = parser.parse_args()
new_quantity = args.integers
customer = "thealternativeboard.com.au"
print(new_quantity)

# TODO: create custom gam python modules: https://groups.google.com/d/topic/google-apps-manager/SF7WaRqKBIk
bashCommand = "export OAUTHFILE=oauth2.txt-itsolver.net; /Users/angusmclauchlan/bin/gam/gam update resoldsubscription {} Google-Apps-Unlimited seats {} {}".format(customer,
                                                                                                                                                                   new_quantity, new_quantity)
process = subprocess.run(bashCommand, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, shell=True, check=True, text=True)
print(process.stdout, process.stderr)

if process.stderr:
    print(process.stderr)
else:
    print(process.stdout)
