"""Check UDP DNS/NTP through the NGFW from an explicit lab data address."""
import socket
import struct
import sys

source = sys.argv[1]
name = b''.join(bytes([len(s)]) + s.encode() for s in 'dmz.bks4.test'.split('.')) + b'\0'
query = struct.pack('!6H', 0x1234, 0x100, 1, 0, 0, 0) + name + struct.pack('!2H', 1, 1)
for port, data in [(53, query), (123, b'\x23' + b'\0' * 47)]:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(5)
        sock.bind((source, 0))
        sock.sendto(data, ('192.168.100.1', port))
        reply, addr = sock.recvfrom(4096)
    if port == 53:
        ident, flags, _, answers, _, _ = struct.unpack('!6H', reply[:12])
        assert ident == 0x1234 and flags & 15 == 0 and answers > 0
        assert reply[-4:] == socket.inet_aton('10.1.50.10')
        print('DNS UDP: dmz.bks4.test -> 10.1.50.10, answers=' + str(answers))
    else:
        assert len(reply) >= 48 and reply[0] & 7 == 4 and 0 < reply[1] < 16
        print('NTP UDP: server reply, stratum=' + str(reply[1]))
