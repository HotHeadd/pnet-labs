# Выполнено на CLIENT. Собственный файл в учебном каталоге DAV.
curl -s -o /dev/null -w 'before=%{http_code}\n' http://192.168.77.20/dav/bks7-review-2711.txt
curl -si -X PUT --data-binary 'BKS7-OWN-TEST-2711' http://192.168.77.20/dav/bks7-review-2711.txt
curl -si http://192.168.77.20/dav/bks7-review-2711.txt
curl -si -X DELETE http://192.168.77.20/dav/bks7-review-2711.txt
curl -s -o /dev/null -w 'after=%{http_code}\n' http://192.168.77.20/dav/bks7-review-2711.txt
