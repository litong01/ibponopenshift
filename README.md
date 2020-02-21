## Deploy IBP onto OpenShift

### Clone this repo and make the tool executable

```
git clone https://github.com/litong01/ibponopenshift.git
cd ibponopenshift && chmod +x ibptool.sh 
```

### Modify mysettings.sh file with your own settings

### Run the following command to start up IBP on OpenShift

```
./ibptool.sh up
```

### Remove IBP from OpenShift
```
./ibptool.sh down
```

### You can change any parameter value by using command line options like this
```
./ibptool.sh up --email-address fake@ddd.com --entitlement-key keyvalue
```
