# kn-echo
Simple Powershell function with an HTTP listener running in Knative to echo
[CloudEvents](https://github.com/cloudevents/).

> **Note:** CloudEvents using structured or binary mode are supported.

# Deployment (Knative)

**Note:** The following steps assume a working Knative environment using the
`default` broker. The Knative `service` and `trigger` will be installed in the
`default` Kubernetes namespace, assuming that the broker is also available there.

```bash
# create the service
kn service create kn-echo --port 8080 --image lamw/kn-echo:latest --scale 1

# create the trigger
cat > trigger.yaml <<EOF
apiVersion: eventing.knative.dev/v1
kind: Trigger
metadata:
  name: veba-echo-trigger
spec:
  broker: rabbit
  subscriber:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: kn-echo
EOF
kubectl apply -f trigger.yaml
```

# Build

```
docker build -t lamw/kn-echo .
```

## Verify the image works by executing it locally:

```bash
docker run -e PORT=8080 -it --rm -p 8080:8080 lamw/kn-echo:latest

# now in a separate window or use -d in the docker cmd above to detach

# Launch PowerShell
pwsh

# Run test Client
./client.ps1
Status Code: 200

# Output from the console running Docker image
Cloud Event
  Source: urn:test
  Subject:
  Id: return-cloud-event
  Data: {
  "a": "b"
}
```