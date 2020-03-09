## Deploy IBP onto OpenShift

### Clone this repo and make the tool executable

```
git clone https://github.com/litong01/ibponopenshift.git
cd ibponopenshift && chmod +x ibptool.sh 
```

### Modify mysettings.sh file with your own settings

For details on how each variable should be set, please see this [tutorial](https://developer.ibm.com/technologies/blockchain/tutorials/deploy-ibm-blockchain-platform-onto-openshift)
### Start up IBP on OpenShift

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

### License
This code pattern is licensed under the Apache Software License, Version 2. Separate third party code objects invoked within this code pattern are licensed by their respective providers pursuant to their own separate licenses. Contributions are subject to the Developer Certificate of Origin, Version 1.1 (DCO) and the Apache Software License, Version 2.
