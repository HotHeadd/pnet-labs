#!/usr/bin/env python3
"""Exercise real IRC/BitTorrent peers on the isolated WAN, with a bound source IP.
No public service, external tracker, exploit, or executable payload is used.
"""
import socket,struct,time,json,hashlib,sys,datetime
source=sys.argv[1];target='192.168.100.1';infohash=bytes.fromhex('95a1a7e4e94239ad013553d1f12aa70ea16e5028')
def exact(s,n):
 data=b''
 while len(data)<n:
  v=s.recv(n-len(data))
  if not v:raise EOFError('Peer closed connection')
  data+=v
 return data
def irc(s,port,out):
 nick='bks4p'+str(port)
 s.sendall(('NICK '+nick+'\r\nUSER bks4 0 * :BKS4 isolated protocol check\r\n').encode())
 data=b''
 while (' 001 '+nick+' ').encode() not in data:
  part=s.recv(8192)
  if not part:raise EOFError('IRC closed before registration')
  data+=part
  if len(data)>65536:raise ValueError('Unexpected IRC response')
 out['irc_registered']=True
 s.sendall(b'PING :bks4-probe\r\n')
 data=b''
 while b'PONG' not in data:
  part=s.recv(8192)
  if not part:raise EOFError('IRC closed before PONG')
  data+=part
 out['irc_pong']=True;s.sendall(b'QUIT :BKS4 test completed\r\n')
def bittorrent(s,port,out):
 peerid=b'-BK0001-'+('%012d'%(time.time_ns()%10**12)).encode()
 s.sendall(b'\x13BitTorrent protocol'+b'\0'*8+infohash+peerid)
 reply=exact(s,68)
 if reply[:20]!=b'\x13BitTorrent protocol' or reply[28:48]!=infohash:raise ValueError('Wrong peer handshake')
 out['bittorrent_handshake']=True
 s.sendall(struct.pack('!IB',1,2)) # interested
 while True:
  size=struct.unpack('!I',exact(s,4))[0]
  if not size:continue
  if size>2*1024*1024:raise ValueError('Unexpected peer message size')
  msg=exact(s,size)
  if msg[0]==1:break # unchoke
 s.sendall(struct.pack('!IBIII',13,6,0,0,16384))
 while True:
  size=struct.unpack('!I',exact(s,4))[0]
  if not size:continue
  if size>2*1024*1024:raise ValueError('Unexpected peer message size')
  msg=exact(s,size)
  if msg[0]==7:
   out['piece_bytes']=len(msg)-9;out['piece_sha256']=hashlib.sha256(msg[9:]).hexdigest();break
for kind,port in [('IRC',6667),('IRC',16667),('BitTorrent',6881),('BitTorrent',16881)]:
 out={'timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':source,'target':target,'port':port,'application':kind};started=time.monotonic()
 try:
  with socket.create_connection((target,port),timeout=15,source_address=(source,0)) as s:
   out['tcp_connected']=True;out['source_port']=s.getsockname()[1]
   (irc if kind=='IRC' else bittorrent)(s,port,out)
   out['result']='success'
 except (OSError,EOFError,ValueError) as e:out['result']=type(e).__name__;out['detail']=str(e)
 out['seconds']=round(time.monotonic()-started,3);print(json.dumps(out),flush=True)
