import urllib.request
import sys

url = "http://127.0.0.1:3000/health"

try:
    raspuns = urllib.request.urlopen(url, timeout=3)
    cod = raspuns.getcode()
    raspuns.close()

    if cod == 200:
        print("Aplicatia functioneaza")
        sys.exit(0)
    else:
        print("Aplicatia nu raspunde corect")
        sys.exit(1)

except Exception:
    print("Nu pot contacta aplicatia")
    sys.exit(1)