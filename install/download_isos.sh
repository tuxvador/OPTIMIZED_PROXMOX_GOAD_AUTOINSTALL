#!/bin/bash

- [Windows-10-22h2_x64_en-us.iso](https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66750/19045.2006.220908-0225.22h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso)
- [windows_server_2016_14393.0_eval_x64.iso](https://software-download.microsoft.com/download/pr/Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.ISO)
- [windows_server2019_x64FREE_en-us.iso](https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/17763.3650.221105-1748.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso)

wget -nc -O "$pfsense_iso_path.gz" "$pfsense_iso_url"

wget -nc -O /var/lib/vz/template/iso/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz https://repo.ialab.dsu.edu/pfsense/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz