# HL7-Msg-Anonymizer

This is a modification of EnsLib.HL7.Message to not display Patient demography information in visual trace.

This feature is toggle by a resource name NotAnonymize, if a user have this resource in USE, then he can see patient demography otherwise not.

Example : 

* SuperUser view :

![SuperUser](https://raw.githubusercontent.com/grongierisc/hl7-msg-anonymizer/master/misc/img/SuperUser.png)

* User without NotAnonymize view :

![main](https://raw.githubusercontent.com/grongierisc/hl7-msg-anonymizer/master/misc/img/Obfuscation.png)

