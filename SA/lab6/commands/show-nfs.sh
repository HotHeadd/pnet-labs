#!/bin/bash
# Короткая демонстрация в терминале WORKSTATION.
set -x
findmnt -n -o SOURCE,TARGET,FSTYPE /mnt/team
sudo -n -u alice ls -ln /mnt/team/alice.txt
sudo -n -u alice cat /mnt/team/alice.txt
alice_exit=$?
sudo -n -u bob cat /mnt/team/alice.txt
bob_exit=$?
sudo -n id -u
sudo -n cat /mnt/team/alice.txt
root_exit=$?
set +x
printf 'alice_exit=%s bob_exit=%s root_exit=%s\n' "$alice_exit" "$bob_exit" "$root_exit"
test "$alice_exit" = 0 && test "$bob_exit" = 1 && test "$root_exit" = 1
