USER=chandan
PASS=vlabs123
DEPSCONTENT=`cat coe_pune_deps`

checkout:
	(for line in $(DEPSCONTENT); do \
	echo $(line); \
	labid=`echo $(line) | awk -F' ' '{print $1}'` ; \
	repotype=`echo $(line) | awk -F' ' '{print $2}'` ;  \
  	reponame=`echo $(line) | awk -F' ' '{print $3}'` ; \
  	echo $(labid) $(repotype) $(reponame) ; \
  	if [ "$(labid)" != "labid" ]; then \
   	rm -rf $(labid) ; \
   	if [ "$(repotype)" == "bzr" ]; then \
    	bzr branch http://$(USER):$(PASS)@bzr.virtual-labs.ac.in/bzr/$(labid)/bzr/$(reponame)/trunk $(labid) ; \
   	fi \
  	fi \
	done)
