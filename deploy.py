import os
import argparse
import fileinput


def _change_to_ipv6(file:str , ipv6: str ):
    tmp_file_name = file + '.copy'
    file_out = open(tmp_file_name, 'w')
    for line in fileinput.input([file], inplace=True):
        if line.strip().startswith('cidr_blocks = '):
            line = '    ipv6_cidr_blocks = ["' + ipv6 + '/128"]' + '\n'
        file_out.write(line)
    file_out.close()
    os.system("mv "+str(tmp_file_name) + " " + str(file))


if __name__ == '__main__':
    description_call = "Parameters for Github, AWS keys, and IP.  Example call:  python3 deploy.py  AKIAIG???????TFJQA  7VzZa???FMCMyrbnA  46.94.7.38 jim-file  /Users/jamespizagno/AWS/ "
    parser = argparse.ArgumentParser(description=description_call)
    parser.add_argument('access_key', help='AWS Access key, or AWSAccessKeyId in zour *key.csv ')
    parser.add_argument('secret_key', help='AWS Secret key, or AWSSecretKey in zour *key.csv ')
    parser.add_argument('user_ip_address', help="Your IP i.e. '46.94.7.38' or 2003:cb:ef20:fb78:c594:17bd:cbbd:d27e")
    parser.add_argument('key_name', help="Name of your AWS Pem file key. so for jpizagno-fil.pem enter 'jpizagno-file' ")
    parser.add_argument('key_path', help="The full file path to your AWS Pem file. i.e. /Users/jpizagno/AWS/ ")
   
    args = parser.parse_args()

    # check for IPV6
    if ":" in args.user_ip_address:
        print("founf IPV6 trying to set ipv6_cidr_blocks ... ")
        _change_to_ipv6('main.tf', args.user_ip_address )

    command = "terraform apply -auto-approve  "
    command = command + " -var 'access_key=" + args.access_key + "' "
    command = command + " -var 'secret_key=" + args.secret_key + "' "
    command = command + " -var 'user_ip_address=" + args.user_ip_address + "' "
    command = command + " -var 'key_name=" + args.key_name + "' "
    command = command + " -var 'key_path=" + args.key_path + "' "
    command = command + " . "

    print("running command 'terraform init  '")
    os.system("terraform init")

    print("running command="+command)
    os.system(command)

