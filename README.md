# HL7-Msg-Anonymizer

This is a modification of EnsLib.HL7.Message to not display Patient demography information in visual trace.

This feature is toggle by a resource name NotAnonymize, if a user have this resource in USE, then he can see patient demography otherwise not.

Example : 

* SuperUser view :

![SuperUser](https://raw.githubusercontent.com/grongierisc/hl7-msg-anonymizer/master/misc/img/SuperUser.png)

* User without NotAnonymize view :

![main](https://raw.githubusercontent.com/grongierisc/hl7-msg-anonymizer/master/misc/img/Obfuscation.png)

# Remarques

First of all, this POC was build on IRIS for Health 2020.3 and it may not work on Ensemble.

In addition, this POC is not supported by InterSystems and is not intended to go into production.

This is not an overload of the EnsLib.HL7.Message class because if we create an overload of this class, the overloaded class could no longer pass through the HL7 routers.
Moreover, with an overloaded class we would need to recreate all the HL7 connectors (TCP, File, FTP, etc).

# How it's build

The project has been constructed in such a way that it is as least intrusive as possible in the original code. 

This makes it possible to take up this idea and eventually apply it to Ensemble.

# How it works



