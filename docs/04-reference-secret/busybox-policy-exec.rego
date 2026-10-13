package agent_policy

import rego.v1

# Secret release is controlled by KBS using the hash of this policy's Init-Data.
# Container creation and image pulling are allowed in both variants.
default CreateContainerRequest := true
default CopyFileRequest := true
default PullImageRequest := true
default ExecProcessRequest := true
default SetPolicyRequest := false
default AllowRequestsFailingPolicy := false

# Allow normal pod lifecycle, networking, and logs. Unlisted requests are denied.
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
default ReadStreamRequest := true
default StatsContainerRequest := true
default GetOOMEventRequest := true
