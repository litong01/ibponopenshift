## Deploy IBP onto OpenShift

### Clone this repo

```
git clone https://github.com/litong01/ibponopenshift.git
cd ibponopenshift && chmod +x ibptool.sh 
```

### Modify mysettings.sh file to fill in your own settings

### Run the following command to start up IBP on OpenShift

```
source mysettings.sh
./ibptool.sh up
```

### Remove IBP from OpenShift
```
source mysettings.sh
./ibptool.sh down
```
