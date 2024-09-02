class GBTStatus:

    def __init__(self):

        self.info = 'Information'

        self.db = MySQLdb.connect(passwd="w3bqu3ry",db="gbt_status",host="gbtdata.gbt.nrao.edu",user="gbtstatus")

        self.cursor = self.db.cursor()

        self.noValue = "unknown"

        self.fieldNames = PSR_fieldNames

        self.prepQuery()

# Security Policy

## Supported Versions

Use this section to tell people about which versions of your project are
currently being supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| 5.1.x   | :white_check_mark: |
| 5.0.x   | :x:                |
| 4.0.x   | :white_check_mark: |
| < 4.0   | :x:                |

## Reporting a Vulnerability

Use this section to tell people how to report a vulnerability.

Tell them where to go, how often they can expect to get an update on a
reported vulnerability, what to expect if the vulnerability is accepted or
declined, etc.
