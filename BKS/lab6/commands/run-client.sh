#!/usr/bin/env bash
set -euo pipefail
server=192.168.106.20
client=192.168.106.10
iface=ens3
ssh_opts=(-o BatchMode=yes -o StrictHostKeyChecking=yes -i "$HOME/.ssh/bks6-peer")
peer="ubuntu@$server"
root=${BKS6_OUTPUT_DIR:-"$HOME/bks6/results"}
mkdir -p "$root"
cd "$root"
capture_pid=
capture_log=

stop_capture() {
    if [ -n "$capture_pid" ]; then
        sleep 1.4
        sudo kill -TERM "$capture_pid" 2>/dev/null || :
        wait "$capture_job" 2>/dev/null || :
        capture_pid=
    fi
}
start_capture() {
    local capture=$1 snaplen=$2 filter=$3
    capture_log="${capture%.pcap}.tcpdump.txt"
    : > "$capture_log"
    sudo -n sh -c 'echo $$ > "$1"; shift; exec tcpdump "$@"' sh "$PWD/capture.pid" \
        -i "$iface" -nn -U -s "$snaplen" -B 16384 -Z "$USER" -w "$PWD/$capture" "$filter" 2>"$capture_log" &
    capture_job=$!
    for _ in {1..50}; do
        if grep -q 'listening on' "$capture_log"; then
            capture_pid=$(cat capture.pid)
            return
        fi
        sleep .1
    done
    cat "$capture_log" >&2
    return 1
}
pair="host $server and host $client"
case ${1:-} in
    transfers)
        trap stop_capture EXIT
        printf 'get /home/ubuntu/bks6/control.txt control-sftp.txt\n' > sftp-get.batch
        start_capture ftp.pcap 0 "$pair"
        curl -fsS --ftp-pasv --netrc-file "$HOME/.bks6-netrc" "ftp://$server/control.txt" -o control-ftp.txt
        stop_capture
        start_capture sftp.pcap 0 "$pair"
        sftp "${ssh_opts[@]}" -b sftp-get.batch "$peer" 2>sftp-client.txt
        stop_capture
        {
            ssh "${ssh_opts[@]}" "$peer" 'sha256sum /home/ubuntu/bks6/control.txt'
            sha256sum control-ftp.txt control-sftp.txt
        } | tee transfer-sha256.txt
        ;;
    scan)
        phase=${2:?specify initial, reject or drop}
        trap stop_capture EXIT
        start_capture "scan-$phase.pcap" 0 "$pair"
        case "$phase" in
            udp-reject|udp-drop)
                sudo -n nmap -n -Pn -sU -p 5300 "$server" -oN "scan-$phase.txt"
                ;;
            initial|reject|drop)
                nmap -n -Pn -sT -p 21,22,8080,8081 "$server" -oN "scan-connect-$phase.txt"
                sudo -n nmap -n -Pn -sS -p 21,22,8080,8081 "$server" -oN "scan-syn-$phase.txt"
                if [ "$phase" = initial ]; then
                    sudo -n nmap -n -Pn -sU -p 53,5300 "$server" -oN scan-udp.txt
                fi
                ;;
            *) exit 2 ;;
        esac
        stop_capture
        ;;
    performance)
        qdisc_before=$(tc qdisc show dev "$iface")
        printf '%s\n' "$qdisc_before" | tee qdisc-before.txt
        case "$qdisc_before" in
            "qdisc fq_codel 0: root "*|"qdisc pfifo_fast 0: root "*) ;;
            *) printf 'Unexpected default queue discipline.\n' >&2; exit 1 ;;
        esac
        netem=0
        cleanup() {
            stop_capture
            if [ "$netem" -eq 1 ]; then
                sudo -n tc qdisc del dev "$iface" root
            fi
            tc qdisc show dev "$iface" | tee qdisc-after.txt
            cmp qdisc-before.txt qdisc-after.txt
        }
        trap cleanup EXIT
        dd if=/dev/urandom of=sample.bin bs=1M count=64 status=none
        sha256sum sample.bin > performance-sha256.txt
        printf 'mode\trun\tseconds\tbytes\n' > performance.tsv
        for mode in baseline delay loss; do
            case "$mode" in
                delay) sudo -n tc qdisc replace dev "$iface" root netem delay 50ms; netem=1 ;;
                loss) sudo -n tc qdisc replace dev "$iface" root netem loss 1% ;;
            esac
            tc -s qdisc show dev "$iface" > "qdisc-$mode.txt"
            for run in 1 2 3; do
                # Capture the first transfer in each series. The data are encrypted.
                if [ "$run" -eq 1 ]; then
                    start_capture "$mode.pcap" 128 "$pair and tcp port 22"
                fi
                printf 'put sample.bin /home/ubuntu/bks6/incoming/%s-%s.bin\n' "$mode" "$run" > sftp-put.batch
                /usr/bin/time -f '%e' -o transfer-time.txt \
                    sftp "${ssh_opts[@]}" -q -b sftp-put.batch "$peer" >>performance-client.txt 2>&1
                if [ "$run" -eq 1 ]; then
                    stop_capture
                fi
                printf '%s\t%s\t%s\t%s\n' "$mode" "$run" "$(cat transfer-time.txt)" "$(stat -c %s sample.bin)" | tee -a performance.tsv
            done
            tc -s qdisc show dev "$iface" > "qdisc-$mode-after.txt"
        done
        ssh "${ssh_opts[@]}" "$peer" 'cd ~/bks6/incoming && sha256sum -- *.bin' >> performance-sha256.txt
        awk 'NR == 1 {hash=$1} $1 != hash {exit 1}' performance-sha256.txt
        ;;
    *) exit 2 ;;
esac
