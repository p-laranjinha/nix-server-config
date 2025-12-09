#! /usr/bin/env nix-shell 
#! nix-shell -i bash -p bash dig

# Run like `./script.sh nixos.org 9.9.9.9 194.242.2.4 1.1.1.1 8.8.8.8` to the
#  the performance of those 4 DNS servers when connecting to 'nixos.org'.

# Get domain name from the first argument
DOMAIN=$1
# Print table header
echo "IP address | Response time"
echo "---------- | -------------"
# Loop through IP addresses and run dig command
for IP in "${@:2}"
do
  # Run dig command and extract response time using awk
  result=$(dig $DOMAIN @$IP | awk '/time/ {print $4 " ms"}')
  # Print IP address and result 
  printf "%-10s | %s\n" "$IP" "$result"
done
