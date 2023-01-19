scripts/build_in_docker.sh
scripts/create_raw_image.sh -d -- disk.raw build/testoperator_kvm-x86_64
scripts/deploy_to_gcp.sh -k unikraft-stable -b unikraft