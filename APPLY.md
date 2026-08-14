# Rancher + telecom bootstrap correction

Apply over the project root:

```bash
unzip -o ~/Downloads/OpenChoreo_Platform_Rancher_Telco_Bootstrap_Fix.zip -d .
chmod +x demo.sh scripts/*.sh
./scripts/self-test.sh
./scripts/bootstrap-telco-data.sh
./demo.sh rancher
curl -ksS https://localhost:8444/ping
./scripts/rancher.sh verify
```

No OpenChoreo reset is required.
