package agent_policy

import rego.v1

# Block command execution and stdout/stderr reads (kubectl exec and logs).
default ExecProcessRequest := false
default ReadStreamRequest := false
default WriteStreamRequest := false
default SetPolicyRequest := false
default AllowRequestsFailingPolicy := false

# Allow container creation, guest image pulling, and normal pod lifecycle.
# This policy restricts access to running containers, not which images may run.
# Unlisted requests are denied.
# The shim copies sandbox setup files into the guest before starting containers.
default CopyFileRequest := true
default CreateContainerRequest := true
default PullImageRequest := true
default CreateSandboxRequest := true
default DestroySandboxRequest := true
default GuestDetailsRequest := true
default OnlineCPUMemRequest := true
default UpdateInterfaceRequest := true
default UpdateRoutesRequest := true
default AddARPNeighborsRequest := true
default StartContainerRequest := true
default RemoveContainerRequest := true
default SignalProcessRequest := true
default WaitProcessRequest := true
default StatsContainerRequest := true
default GetOOMEventRequest := true
