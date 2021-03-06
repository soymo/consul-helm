#!/usr/bin/env bats

load _helpers

@test "server/StatefulSet: enabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: enable with global.enabled false" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'global.enabled=false' \
      --set 'server.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: disable with server.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server/StatefulSet: disable with global.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'global.enabled=false' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

#--------------------------------------------------------------------
# image

@test "server/StatefulSet: image defaults to global.image" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'global.image=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "foo" ]
}

@test "server/StatefulSet: image can be overridden with server.image" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'global.image=foo' \
      --set 'server.image=bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

#--------------------------------------------------------------------
# resources

@test "server/StatefulSet: no resources defined by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].resources' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "server/StatefulSet: resources can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.resources=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].resources' | tee /dev/stderr)
  [ "${actual}" = "foo" ]
}

#--------------------------------------------------------------------
# updateStrategy (derived from updatePartition)

@test "server/StatefulSet: no updateStrategy when not updating" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.updateStrategy' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "server/StatefulSet: updateStrategy during update" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.updatePartition=2' \
      . | tee /dev/stderr |
      yq -r '.spec.updateStrategy.type' | tee /dev/stderr)
  [ "${actual}" = "RollingUpdate" ]

  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.updatePartition=2' \
      . | tee /dev/stderr |
      yq -r '.spec.updateStrategy.rollingUpdate.partition' | tee /dev/stderr)
  [ "${actual}" = "2" ]
}

#--------------------------------------------------------------------
# storageClass

@test "server/StatefulSet: no storageClass on claim by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.volumeClaimTemplates[0].spec.storageClassName' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "server/StatefulSet: can set storageClass" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.storageClass=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.volumeClaimTemplates[0].spec.storageClassName' | tee /dev/stderr)
  [ "${actual}" = "foo" ]
}

#--------------------------------------------------------------------
# extraVolumes

@test "server/StatefulSet: adds extra volume" {
  cd `chart_dir`

  # Test that it defines it
  local object=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.volumes[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.configMap.name' | tee /dev/stderr)
  [ "${actual}" = "foo" ]

  local actual=$(echo $object |
      yq -r '.configMap.secretName' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  # Test that it mounts it
  local object=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.readOnly' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object |
      yq -r '.mountPath' | tee /dev/stderr)
  [ "${actual}" = "/consul/userconfig/foo" ]

  # Doesn't load it
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].command | map(select(test("userconfig"))) | length' | tee /dev/stderr)
  [ "${actual}" = "0" ]
}

@test "server/StatefulSet: adds extra secret volume" {
  cd `chart_dir`

  # Test that it defines it
  local object=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=secret' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.volumes[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.secret.name' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  local actual=$(echo $object |
      yq -r '.secret.secretName' | tee /dev/stderr)
  [ "${actual}" = "foo" ]

  # Test that it mounts it
  local object=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.readOnly' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object |
      yq -r '.mountPath' | tee /dev/stderr)
  [ "${actual}" = "/consul/userconfig/foo" ]

  # Doesn't load it
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].command | map(select(test("userconfig"))) | length' | tee /dev/stderr)
  [ "${actual}" = "0" ]
}

@test "server/StatefulSet: adds loadable volume" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      --set 'server.extraVolumes[0].load=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].command | map(select(test("/consul/userconfig/foo"))) | length' | tee /dev/stderr)
  [ "${actual}" = "1" ]
}

#--------------------------------------------------------------------
# affinity

@test "server/StatefulSet: affinity not set with server.affinity=null" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      --set 'server.affinity=null' \
      . | tee /dev/stderr |
      yq '.spec.template.spec | .affinity? == null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: affinity set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -x templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.affinity | .podAntiAffinity? != null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}
