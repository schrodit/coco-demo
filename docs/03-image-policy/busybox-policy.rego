package agent_policy

import rego.v1

# For CoCo guest image pulling (image_guest_pull), not host-pulled rootfs images.
# Pin the same BusyBox digest used by busybox.yaml.
busybox_image := "docker.io/library/busybox@sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e"

default CreateContainerRequest := false
default CopyFileRequest := false
default ExecProcessRequest := false
default SetPolicyRequest := false
default AllowRequestsFailingPolicy := false

# Allow pod lifecycle, networking, and logs. Unlisted requests are denied.
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

# The shim stages sandbox setup files and projected volumes in the guest.
# Match Kata's shared-file naming convention, not arbitrary guest/rootfs paths.
CopyFileRequest if {
    regex.match("^/run/kata-containers/shared/containers(/passthrough)?/(watchable/)?[a-z0-9]{64}-[a-z0-9]{16}-[^/]+(/[^/]+)*$", input.path)
    every segment in split(input.path, "/") {
        segment != "."
        segment != ".."
    }
}

CreateContainerRequest if {
    input.OCI.Annotations["io.kubernetes.cri.container-type"] == "container"
    valid_image_storage(busybox_image)
}

# CoCo uses the guest's built-in pause image for the Kubernetes sandbox.
# This exception does not allow an arbitrary registry pause image.
CreateContainerRequest if {
    input.OCI.Annotations["io.kubernetes.cri.container-type"] == "sandbox"
    input.OCI.Process.Args == ["/pause"]
    valid_image_storage("pause")
}

valid_image_storage(image) if {
    image_storages := [storage | some storage in input.storages; storage.driver == "image_guest_pull"]
    count(image_storages) == 1
    rootfs := image_storages[0]
    rootfs.source == image
    rootfs.fstype == "overlay"
    rootfs.mount_point == input.OCI.Root.Path

    # Do not accept another storage driver as an alternative root filesystem.
    every storage in input.storages {
        allowed_storage(storage)
    }
}

allowed_storage(storage) if {
    storage.driver == "image_guest_pull"
}

allowed_storage(storage) if {
    storage.driver in {"ephemeral", "local", "watchable-bind"}
    storage.mount_point != input.OCI.Root.Path
    not startswith(storage.mount_point, concat("", [input.OCI.Root.Path, "/"]))
}
