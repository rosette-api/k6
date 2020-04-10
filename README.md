# Introduction
This demo contains a k6 setup. This can be used to:
1. Demonstrate the horizontal scaling of a Rosette Enterprise application deployed in k8s.
2. Perform functional testing of Rosette Enterprise.

Steps used to generate the included test files:
1. Develop a Postman test collection based on the Rosette API interactive documentation.
2. Export the collection to version v2.1 of the Postman collection format.
3. Use the postman-to-k6 tool to convert the Postman collection to k6 scripts https://github.com/loadimpact/postman-to-k6


# What is Included
This demo includes all the files needed to run the pre-generated k6 tests.

|Files included in the demo   |   |
|----|-------|
|File|Purpose|
|RosetteEnterprise.postman_collection.json|The exported Postman collection|
|Localhost.postman_environment.json|Environment variables used in the collection|
|fixupscript.sh|Helper script to clean up the k6 script when re-generating the k6 script (described below)|
|README.md|This file|
|./tests/rosent-tests.js|The pre-generated k6 test script|
|./tests/libs/*|JavaScript libraries used by rosent-tests.js|

## Running tests
There are several ways to run k6, please refer to https://k6.io/docs/ for more complete coverage of the various options. For the purposes of this demo k6 will be used create a high load on a k8s-deployed Rosette Enterprise application which will cause k8s to horizontally autoscale the number of active Pods. K6 does this by simulating a high number of virtual users running for several minutes. In addition to stress testing k8s, the k6 script can be used to perform basic validation of the Rosette Enterprise deployment.

### Stress Test
To stress test the k8s deployment the k6 tests must simulate a large number of users to push the CPU threshold over the Horizontal Pod Autoscaler (HPA) threshold and start a new Pod. Before running the test, determine the number of Pods currently running and if there are available Pods to scale to `$kubectl get pods`. Running `$kubectl get hpa` will list the Horizontal Pod Autoscaler settings and current threshold.
```
# validation of the setup of the application using one virtual user
# in the ./tests directory
#
$ k6 run --vus=1 -e TEST_HOST_PORT=[IP of k8s loadbalancer]:8181 rosent-tests.js

# Note the -e parameter specifies environment variables on the command line.
# Environment variables can also be exported instead if that is preferred.
#
$ export TEST_HOST_PORT=[IP of k8s loadbalancer]:8181
$ k6 run --vus=1 rosent-tests.js

# if everything is configured correctly then the tests will pass and it is time
# to move on to stress testing. Note, some latency tests may take
# longer than 200ms and fail depending on the Node types in the k8s cluster.
# These failures can be ignored. Also, depending on the Node hardware definitions
# the number of virtual users (vus) used below may need to be increased in order
# to push the HPA threshold over the limit.
#
$ k6 run --vus=20 --duration=120s -e TEST_HOST_PORT=[IP of k8s loadbalancer]:8181 rosent-tests.js

# in a separate command window the following commands
# will show the number of Pods running and the HPA
# thresholds
#
$kubectl get pods
$kubectl get hpa

```
When the test is running the number of Pods should increase once the HPA's threshold has been hit. If the threshold is not hit, increase the number of virtual users and re-run the test until the threshold is hit. Note, the default scale down time in k8s is 5 minutes so the additional Pods will remain active until the scale down time has elapsed.

### Generating a test archive
A tar file can be generated using the archive option of k6 that bundles the script and libraries into one file that can be executed directly by k6. The use of archives makes it easier to share test suites and to create Docker images since only one file needs to be manipulated. This is a simple tar file that can be expanded and modified as needed. To create the archive run the following:
```
# In the ./tests directory
$ k6 archive rosent-tests.js -O rosent-tests.tar
```
Any tar file name can be used as output, the default name is archive.tar which is slightly non-descriptive. To run the archive:
```
$ k6 run -e TEST_HOST_PORT=[IP of k8s loadbalancer]:8181 rosent-tests.tar
```

# Modifying the test suite

## Postman Test Collection
The test collection export is defined in `RosetteEnterprise.postman_collection.json` and is based on the sample data from the interactive documents at `api.rosette.com`. Since features may or may not be licensed by an installation of Rosette Enterprise, each test will check the HTTP response code for a 403 indicating an unlicensed endpoint. If the endpoint is not licensed then the test is assumed to be successful. There is a mix of tests defined in the test collection, some tests examine value ranges of responses, content of responses, and simple HTTP status code validation. The collection can be viewed by importing it into Postman. Two variables are used to run the tests in Postman, `XRosetteAPIKey` which is used for testing Rosette API and `baseUrl` which is used for both Rosette Enterprise and API. The `baseUrl` should be defined as follows `http://localhost:8181/rest/v1` of course customized for the target environment. The XRosetteAPIKey will be sent in the X-RosetteAPI-Key HTTP header.

## Exporting the Test Collection
Exporting the test collection has already been done for this demo. If new tests are added or changed in Postman, the test collection will need to be exported again and converted to k6 scripts. In Postman, right-click on the collection name, select export version 2.1, and select a directory to save the collection to. If additional environment variables are added to the test collection then they will need to be exported again as well.

The environment settings, baseUrl and XRosetteAPIKey have been exported from Postman. To export environment settings from Postman, click on the 'gear' symbol and download the environment that contains the environment settings. The file `Localhost.postman_environment.json` contains the variables used in these tests. Note, environment settings can be imported into Postman as well.

## Using the postman-to-k6 tool
The postman-to-k6 tool can be installed in a number of ways: npm, yarn, or Docker as outlined at `https://github.com/loadimpact/postman-to-k6`. We  recommend you create a subdirectory to store the generated k6 tests, for example `./tests`. To run the tool specify the collection, environment file, and a script to output the tests to.

```
$ postman-to-k6 RosetteEnterprise.postman_collection.json -e Localhost.postman_environment.json -o ./tests/rosent-tests.js
```
Once this command is executed `./tests` will contain a directory, `libs`, that holds helper libraries needed by k6 and one JavaScript file `rosent-tests.js`. The `rosent-tests.js` file holds all the tests from Postman.

The provided `Localhost.postman_environment.json` has a special value for the `value` property of `baseUrl` which leverages k6's ability to use environment variables. The provided property is ``"value": "`http://${__ENV.TEST_HOST_PORT}/rest/v1`",``.  Note the `` `" `` and `` "` `` in the property value. Once the k6 scripts have been created using the `postman-to-k6` command then the `` `" and "` `` will need to be replaced with a single `` ` `` in the `rosent-tests.js` file. To facilitate this, a bash script, fixupscript.sh, will perform the replacement. Once the k6 script has been generated, run fixupscript.sh on the generated js file. For example, `$./fixupscript.sh ./tests/rosent-tests.js` If you would rather hardcode the host and port of the system under test (SUT) edit `Localhost.postman_environment.json` and replace the `value` property of `baseUrl` with the URL of the SUT explicitly. For example:

``"value": "`http://${__ENV.TEST_HOST_PORT}/rest/v1`",``

can be changed to

``"value": "http://localhost:8181/rest/v1",``

Explicitly setting the value eliminates the need to run the fixupscript.sh on the script. However, the advantage of using the command line/environment variable is that the test script does not have to be changed to test a new host.

