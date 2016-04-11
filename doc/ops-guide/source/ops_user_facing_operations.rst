======================
User-Facing Operations
======================

This guide is for OpenStack operators and does not seek to be an
exhaustive reference for users, but as an operator, you should have a
basic understanding of how to use the cloud facilities. This chapter
looks at OpenStack from a basic user perspective, which helps you
understand your users' needs and determine, when you get a trouble
ticket, whether it is a user issue or a service issue. The main concepts
covered are images, flavors, security groups, block storage, shared file
system storage, and instances.

Images
~~~~~~

OpenStack images can often be thought of as "virtual machine templates."
Images can also be standard installation media such as ISO images.
Essentially, they contain bootable file systems that are used to launch
instances.

Adding Images
-------------

Several pre-made images exist and can easily be imported into the Image
service. A common image to add is the CirrOS image, which is very small
and used for testing purposes.images adding To add this image, simply
do:

.. code-block:: console

   $ wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
   $ glance image-create --name='cirros image' --is-public=true \
     --container-format=bare --disk-format=qcow2 < cirros-0.3.4-x86_64-disk.img

The :command:`glance image-create` command provides a large set of options for
working with your image. For example, the `` min-disk`` option is useful
for images that require root disks of a certain size (for example, large
Windows images). To view these options, do:

.. code-block:: console

   $ glance help image-create

The ``location`` option is important to note. It does not copy the
entire image into the Image service, but references an original location
where the image can be found. Upon launching an instance of that image,
the Image service accesses the image from the location specified.

The ``copy-from`` option copies the image from the location specified
into the ``/var/lib/glance/images`` directory. The same thing is done
when using the STDIN redirection with <, as shown in the example.

Run the following command to view the properties of existing images:

.. code-block:: console

   $ glance image-show <image-uuid>

Adding Signed Images
--------------------

To provide a chain of trust from an end user to the Image service, and
the Image service to Compute, an end user can import signed images into
the Image service that can be verified in Compute. Appropriate Image
service properties need to be set to enable signature verification.
Currently, signature verification is provided in Compute only, but an
accompanying feature in the Image service is targeted for :term:`Mitaka`.

.. note::

   Prior to the steps below, an asymmetric keypair and certificate must
   be generated. In this example, these are called private_key.pem and
   new_cert.crt, respectively, and both reside in the current
   directory. Also note that the image in this example is
   cirros-0.3.4-x86_64-disk.img, but any image can be used.

The following are steps needed to create the signature used for the
signed images:

#. Retrieve image for upload

   .. code-block:: console

      $ wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img > cirros-0.3.4-x86_64-disk.img

#. Use private key to create a signature of the image

   .. note::

      The following implicit values are being used to create the signature
      in this example:

      -  Signature hash method = SHA-256

      -  Signature key type = RSA-PSS

   .. note::

      The following options are currently supported:

      -  Signature hash methods: SHA-224, SHA-256, SHA-384, and SHA-512

      -  Signature key types: DSA, ECC_SECT571K1, ECC_SECT409K1,
         ECC_SECT571R1, ECC_SECT409R1, ECC_SECP521R1, ECC_SECP384R1,
         and RSA-PSS

   Generate signature of image and convert it to a base64 representation:

   .. code-block:: console

      $ openssl dgst -sha256 -sign private_key.pem -sigopt rsa_padding_mode:\
              pss -out image-file.signature cirros-0.3.4-x86_64-disk.img

   .. code-block:: console

      $ base64 image-file.signature > signature_64

   .. code-block:: console

      $ cat signature_64
      'c4br5f3FYQV6Nu20cRUSnx75R/VcW3diQdsUN2nhPw+UcQRDoGx92hwMgRxzFYeUyydRTWCcUS2ZLudPR9X7rM
      THFInA54Zj1TwEIbJTkHwlqbWBMU4+k5IUIjXxHO6RuH3Z5f/SlSt7ajsNVXaIclWqIw5YvEkgXTIEuDPE+C4='

#. Create context

   .. code-block:: python

      $ python
      >>> from keystoneclient.v3 import client
      >>> keystone_client = client.Client(username='demo',
                                          user_domain_name='Default',
                                          password='password',
                                          project_name='demo',
                                          auth_url='http://localhost:5000/v3')

      >>> from oslo_context import context
      >>> context = context.RequestContext(auth_token=keystone_client.auth_token,
                                           tenant=keystone_client.project_id)

#. Encode certificate in DER format

   .. code-block:: python

      >>> from cryptography import x509 as cryptography_x509
      >>> from cryptography.hazmat import backends
      >>> from cryptography.hazmat.primitives import serialization
      >>> with open("new_cert.crt", "rb") as cert_file:
      >>>      cert = cryptography_x509.load_pem_x509_certificate(
                        cert_file.read(),
                        backend=backends.default_backend()
                        )
      >>> certificate_der = cert.public_bytes(encoding=serialization.Encoding.DER)

#. Upload Certificate in DER format to Castellan

   .. code-block:: python

      >>> from castellan.common.objects import x_509
      >>> from castellan import key_manager
      >>> castellan_cert = x_509.X509(certificate_der)
      >>> key_API = key_manager.API()
      >>> cert_uuid = key_API.store(context, castellan_cert)
      >>> cert_uuid
      u'62a33f41-f061-44ba-9a69-4fc247d3bfce'

#. Upload Image to Image service, with Signature Metadata

   .. note::

      The following signature properties are used:

      -  img_signature uses the signature called signature_64

      -  img_signature_certificate_uuid uses the value from cert_uuid
         in section 5 above

      -  img_signature_hash_method matches 'SHA-256' in section 2 above

      -  img_signature_key_type matches 'RSA-PSS' in section 2 above

   .. code-block:: console

      $ source openrc demo
      $ export OS_IMAGE_API_VERSION=2
      $ glance image-create\
      --property name=cirrosSignedImage_goodSignature\
      --property is-public=true\
      --container-format bare\
      --disk-format qcow2\
      --property img_signature='c4br5f3FYQV6Nu20cRUSnx75R/VcW3diQdsUN2nhPw+UcQRDoGx92hwM
      gRxzFYeUyydRTWCcUS2ZLudPR9X7rMTHFInA54Zj1TwEIbJTkHwlqbWBMU4+k5IUIjXxHO6RuH3Z5f/
      SlSt7ajsNVXaIclWqIw5YvEkgXTIEuDPE+C4='\
      --property img_signature_certificate_uuid='62a33f41-f061-44ba-9a69-4fc247d3bfce'\
      --property img_signature_hash_method='SHA-256'\
      --property img_signature_key_type='RSA-PSS'\
      < ~/cirros-0.3.4-x86_64-disk.img

#. Signature verification will occur when Compute boots the signed image

   .. note::

      As of the Mitaka release, Compute supports instance signature
      validation. This is enabled by setting the
      verify_glance_signatures flag in nova.conf to TRUE. When enabled,
      Compute will automatically validate signed instances prior to its
      launch.

Sharing Images Between Projects
-------------------------------

In a multi-tenant cloud environment, users sometimes want to share their
personal images or snapshots with other projects.projects sharing images
betweenimages sharing between projects This can be done on the command
line with the ``glance`` tool by the owner of the image.

To share an image or snapshot with another project, do the following:

#. Obtain the UUID of the image:

   .. code-block:: console

      $ glance image-list

#. Obtain the UUID of the project with which you want to share your image.
   Unfortunately, non-admin users are unable to use the :command:`keystone`
   command to do this. The easiest solution is to obtain the UUID either
   from an administrator of the cloud or from a user located in the
   project.

#. Once you have both pieces of information, run
   the :command:`glance` command:

   .. code-block:: console

      $ glance member-create <image-uuid> <project-uuid>

   For example:

   .. code-block:: console

      $ glance member-create 733d1c44-a2ea-414b-aca7-69decf20d810 \
          771ed149ef7e4b2b88665cc1c98f77ca

   Project 771ed149ef7e4b2b88665cc1c98f77ca will now have access to image
   733d1c44-a2ea-414b-aca7-69decf20d810.

Deleting Images
---------------

To delete an image,images deleting just execute:

.. code-block:: console

   $ glance image-delete <image uuid>

.. note::

   Deleting an image does not affect instances or snapshots that were
   based on the image.

Other CLI Options
-----------------

A full set of options can be found using:images CLI options for

.. code-block:: console

   $ glance help

or the `Command-Line Interface
Reference <http://docs.openstack.org/cli-reference/glance.html>`__.

The Image service and the Database
----------------------------------

The only thing that the Image service does not store in a database is
the image itself. The Image service database has two main
tables:

-  ``images``

-  ``image_properties``

Working directly with the database and SQL queries can provide you with
custom lists and reports of images. Technically, you can update
properties about images through the database, although this is not
generally recommended.

Example Image service Database Queries
--------------------------------------

One interesting example is modifying the table of images and the owner
of that image. This can be easily done if you simply display the unique
ID of the owner. Image service database queriesThis example goes one
step further and displays the readable name of the owner:

.. code-block:: console

   mysql> select glance.images.id,
                 glance.images.name, keystone.tenant.name, is_public from
                 glance.images inner join keystone.tenant on
                 glance.images.owner=keystone.tenant.id;

Another example is displaying all properties for a certain image:

.. code-block:: console

   mysql> select name, value from
                 image_properties where id = <image_id>

Flavors
~~~~~~~

Virtual hardware templates are called "flavors" in OpenStack, defining
sizes for RAM, disk, number of cores, and so on. The default install
provides five flavors.

These are configurable by admin users (the rights may also be delegated
to other users by redefining the access controls for
``compute_extension:flavormanage`` in ``/etc/nova/policy.json`` on the
``nova-api`` server). To get the list of available flavors on your
system, run:

.. code-block:: console

   $ nova flavor-list
   +-----+-----------+-----------+------+-----------+------+-------+-------------+-----------+
   | ID  | Name      | Memory_MB | Disk | Ephemeral | Swap | VCPUs | RXTX_Factor | Is_Public |
   +-----+-----------+-----------+------+-----------+------+-------+-------------+-----------+
   | 1   | m1.tiny   | 512       | 1    | 0         |      | 1     | 1.0         | True      |
   | 2   | m1.small  | 2048      | 20   | 0         |      | 1     | 1.0         | True      |
   | 3   | m1.medium | 4096      | 40   | 0         |      | 2     | 1.0         | True      |
   | 4   | m1.large  | 8192      | 80   | 0         |      | 4     | 1.0         | True      |
   | 5   | m1.xlarge | 16384     | 160  | 0         |      | 8     | 1.0         | True      |
   +-----+-----------+-----------+------+-----------+------+-------+-------------+-----------+

The :command:`nova flavor-create` command allows authorized users to create
new flavors. Additional flavor manipulation commands can be shown with the
command:

.. code-block:: console

   $ nova help | grep flavor

Flavors define a number of parameters, resulting in the user having a
choice of what type of virtual machine to run—just like they would have
if they were purchasing a physical server. The below table lists the elements
that can be set. Note in particular ``extra_specs``, which can be used to
define free-form characteristics, giving a lot of flexibility beyond just the
size of RAM, CPU, and Disk.

.. list-table:: Flavor parameters
   :widths: 50 50
   :header-rows: 1

   * - **Column**
     - **Description**
   * - ID
     - Unique ID (integer or UUID) for the flavor.
   * - Name
     - A descriptive name, such as xx.size\_name, is conventional but not required, though some third-party tools may rely on it.
   * - Memory\_MB
     - Virtual machine memory in megabytes.
   * - Disk
     - Virtual root disk size in gigabytes. This is an ephemeral disk the base image is copied into. You don't use it when you boot from a persistent volume. The "0" size is a special case that uses the native base image size as the size of the ephemeral root volume.
   * - Ephemeral
     - Specifies the size of a secondary ephemeral data disk. This is an empty, unformatted disk and exists only for the life of the instance.
   * - Swap
     - Optional swap space allocation for the instance.
   * - VCPUs
     - Number of virtual CPUs presented to the instance.
   * - RXTX_Factor
     - Optional property that allows created servers to have a different
       bandwidthbandwidth capping cap from that defined in the network
       they are attached to. This factor is multiplied by the rxtx\_base
       property of the network.
       Default value is 1.0 (that is, the same as the attached network).
   * - Is_Public
     - Boolean value that indicates whether the flavor is available to
       all users or private. Private flavors do not get the current
       tenant assigned to them. Defaults to ``True``.
   * - extra_specs
     - Additional optional restrictions on which compute nodes the
       flavor can run on. This is implemented as key-value pairs that must
       match against the corresponding key-value pairs on compute nodes.
       Can be used to implement things like special resources (such as
       flavors that can run only on compute nodes with GPU hardware).


Private Flavors
---------------

A user might need a custom flavor that is uniquely tuned for a project
she is working on. For example, the user might require 128 GB of memory.
If you create a new flavor as described above, the user would have
access to the custom flavor, but so would all other tenants in your
cloud. Sometimes this sharing isn't desirable. In this scenario,
allowing all users to have access to a flavor with 128 GB of memory
might cause your cloud to reach full capacity very quickly. To prevent
this, you can restrict access to the custom flavor using the
:command:`nova` command:

.. code-block:: console

   $ nova flavor-access-add <flavor-id> <project-id>

To view a flavor's access list, do the following:

.. code-block:: console

   $ nova flavor-access-list <flavor-id>

.. note::

   Once access to a flavor has been restricted, no other projects
   besides the ones granted explicit access will be able to see the
   flavor. This includes the admin project. Make sure to add the admin
   project in addition to the original project.

   It's also helpful to allocate a specific numeric range for custom
   and private flavors. On UNIX-based systems, nonsystem accounts
   usually have a UID starting at 500. A similar approach can be taken
   with custom flavors. This helps you easily identify which flavors
   are custom, private, and public for the entire cloud.

**How Do I Modify an Existing Flavor?**

The OpenStack dashboard simulates the ability to modify a flavor by
deleting an existing flavor and creating a new one with the same name.

Security Groups
~~~~~~~~~~~~~~~

A common new-user issue with OpenStack is failing to set an appropriate
security group when launching an instance. As a result, the user is
unable to contact the instance on the network.

Security groups are sets of IP filter rules that are applied to an
instance's networking. They are project specific, and project members
can edit the default rules for their group and add new rules sets. All
projects have a "default" security group, which is applied to instances
that have no other security group defined. Unless changed, this security
group denies all incoming traffic.

General Security Groups Configuration
-------------------------------------

The ``nova.conf`` option ``allow_same_net_traffic`` (which defaults to
``true``) globally controls whether the rules apply to hosts that share
a network. When set to ``true``, hosts on the same subnet are not
filtered and are allowed to pass all types of traffic between them. On a
flat network, this allows all instances from all projects unfiltered
communication. With VLAN networking, this allows access between
instances within the same project. If ``allow_same_net_traffic`` is set
to ``false``, security groups are enforced for all connections. In this
case, it is possible for projects to simulate ``allow_same_net_traffic``
by configuring their default security group to allow all traffic from
their subnet.

.. note::

   As noted in the previous chapter, the number of rules per security
   group is controlled by the ``quota_security_group_rules``, and the
   number of allowed security groups per project is controlled by the
   ``quota_security_groups`` quota.

End-User Configuration of Security Groups
-----------------------------------------

Security groups for the current project can be found on the OpenStack
dashboard under :guilabel:`Access & Security`. To see details of an
existing group, select the :guilabel:`edit` action for that security group.
Obviously, modifying existing groups can be done from this edit interface.
There is a :guilabel:`Create Security Group` button on the main
**Access & Security** page for creating new groups. We discuss the terms
used in these fields when we explain the command-line equivalents.

**Setting with nova command**

From the command line, you can get a list of security groups for the
project you're acting in using the :command:`nova` command:

.. code-block:: console

   $ nova secgroup-list
   +---------+-------------+
   | Name    | Description |
   +---------+-------------+
   | default | default     |
   | open    | all ports   |
   +---------+-------------+

To view the details of the "open" security group:

.. code-block:: console

   $ nova secgroup-list-rules open
   +-------------+-----------+---------+-----------+--------------+
   | IP Protocol | From Port | To Port | IP Range  | Source Group |
   +-------------+-----------+---------+-----------+--------------+
   | icmp        | -1        | 255     | 0.0.0.0/0 |              |
   | tcp         | 1         | 65535   | 0.0.0.0/0 |              |
   | udp         | 1         | 65535   | 0.0.0.0/0 |              |
   +-------------+-----------+---------+-----------+--------------+

These rules are all "allow" type rules, as the default is deny. The
first column is the IP protocol (one of icmp, tcp, or udp), and the
second and third columns specify the affected port range. The fourth
column specifies the IP range in CIDR format. This example shows the
full port range for all protocols allowed from all IPs.

When adding a new security group, you should pick a descriptive but
brief name. This name shows up in brief descriptions of the instances
that use it where the longer description field often does not. Seeing
that an instance is using security group ``http`` is much easier to
understand than ``bobs_group`` or ``secgrp1``.

As an example, let's create a security group that allows web traffic
anywhere on the Internet. We'll call this group ``global_http``, which
is clear and reasonably concise, encapsulating what is allowed and from
where. From the command line, do:

.. code-block:: console

   $ nova secgroup-create \
            global_http "allow web traffic from the Internet"
   +-------------+-------------------------------------+
   | Name        | Description                         |
   +-------------+-------------------------------------+
   | global_http | allow web traffic from the Internet |
   +-------------+-------------------------------------+

This creates the empty security group. To make it do what we want, we
need to add some rules:

.. code-block:: console

   $ nova secgroup-add-rule <secgroup> <ip-proto> <from-port> <to-port> <cidr>
   $ nova secgroup-add-rule global_http tcp 80 80 0.0.0.0/0
   +-------------+-----------+---------+-----------+--------------+
   | IP Protocol | From Port | To Port | IP Range  | Source Group |
   +-------------+-----------+---------+-----------+--------------+
   | tcp         | 80        | 80      | 0.0.0.0/0 |              |
   +-------------+-----------+---------+-----------+--------------+

Note that the arguments are positional, and the ``from-port`` and
``to-port`` arguments specify the allowed local port range connections.
These arguments are not indicating source and destination ports of the
connection. More complex rule sets can be built up through multiple
invocations of :command:`nova secgroup-add-rule`. For example, if you want to
pass both http and https traffic, do this:

.. code-block:: console

   $ nova secgroup-add-rule global_http tcp 443 443 0.0.0.0/0
   +-------------+-----------+---------+-----------+--------------+
   | IP Protocol | From Port | To Port | IP Range  | Source Group |
   +-------------+-----------+---------+-----------+--------------+
   | tcp         | 443       | 443     | 0.0.0.0/0 |              |
   +-------------+-----------+---------+-----------+--------------+

Despite only outputting the newly added rule, this operation is
additive:

.. code-block:: console

   $ nova secgroup-list-rules global_http
   +-------------+-----------+---------+-----------+--------------+
   | IP Protocol | From Port | To Port | IP Range  | Source Group |
   +-------------+-----------+---------+-----------+--------------+
   | tcp         | 80        | 80      | 0.0.0.0/0 |              |
   | tcp         | 443       | 443     | 0.0.0.0/0 |              |
   +-------------+-----------+---------+-----------+--------------+

The inverse operation is called :command:`secgroup-delete-rule`, using the
same format. Whole security groups can be removed with
:command:`secgroup-delete`.

To create security group rules for a cluster of instances, you want to
use SourceGroups.

SourceGroups are a special dynamic way of defining the CIDR of allowed
sources. The user specifies a SourceGroup (security group name) and then
all the users' other instances using the specified SourceGroup are
selected dynamically. This dynamic selection alleviates the need for
individual rules to allow each new member of the cluster.

The code is structured like this:

.. code-block:: console

   nova secgroup-add-group-rule <secgroup> <source-group> <ip-proto> <from-port> <to-port>

An example usage is shown here:

.. code-block:: console

   $ nova secgroup-add-group-rule cluster global-http tcp 22 22

The "cluster" rule allows SSH access from any other instance that uses
the ``global-http`` group.

**Setting with neutron command**

If your environment is using Neutron, you can configure security groups
settings using the :command:`neutron` command. Get a list of security groups
for the project you are acting in, by using following command:

.. code-block:: console

   $ neutron security-group-list
   +--------------------------------------+---------+-------------+
   | id                                   | name    | description |
   +--------------------------------------+---------+-------------+
   | 6777138a-deb7-4f10-8236-6400e7aff5b0 | default | default     |
   | 750acb39-d69b-4ea0-a62d-b56101166b01 | open    | all ports   |
   +--------------------------------------+---------+-------------+

To view the details of the "open" security group:

.. code-block:: console

   $ neutron security-group-show open
   +----------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
   | Field                | Value                                                                                                                                                                                                                                                                                                                                  |
   +----------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
   | description          | all ports                                                                                                                                                                                                                                                                                                                              |
   | id                   | 750acb39-d69b-4ea0-a62d-b56101166b01                                                                                                                                                                                                                                                                                                   |
   | name                 | open                                                                                                                                                                                                                                                                                                                                   |
   | security_group_rules | {"remote_group_id": null, "direction": "egress", "remote_ip_prefix": null, "protocol": null, "tenant_id": "607ec981611a4839b7b06f6dfa81317d", "port_range_max": null, "security_group_id": "750acb39-d69b-4e0-a62d-b56101166b01", "port_range_min": null, "ethertype": "IPv4", "id": "361a1b62-95dd-46e1-8639-c3b2000aab60"}           |
   |                      | {"remote_group_id": null, "direction": "ingress", "remote_ip_prefix": "0.0.0.0/0", "protocol": "udp", "tenant_id": "341f49145ec7445192dc3c2abc33500d", "port_range_max": 65535, "security_group_id": "750acb9-d69b-4ea0-a62d-b56101166b01", "port_range_min": 1, "ethertype": "IPv4", "id": "496ba8b7-d96e-4655-920f-068a3d4ddc36"}    |
   |                      | {"remote_group_id": null, "direction": "ingress", "remote_ip_prefix": "0.0.0.0/0", "protocol": "icmp", "tenant_id": "341f49145ec7445192dc3c2abc33500d", "port_range_max": null, "security_group_id": "750acb9-d69b-4ea0-a62d-b56101166b01", "port_range_min": null, "ethertype": "IPv4", "id": "50642a56-3c4e-4b31-9293-0a636759a156"} |
   |                      | {"remote_group_id": null, "direction": "egress", "remote_ip_prefix": null, "protocol": null, "tenant_id": "607ec981611a4839b7b06f6dfa81317d", "port_range_max": null, "security_group_id": "750acb39-d69b-4e0-a62d-b56101166b01", "port_range_min": null, "ethertype": "IPv6", "id": "f46f35eb-8581-4ca1-bbc9-cf8d0614d067"}           |
   |                      | {"remote_group_id": null, "direction": "ingress", "remote_ip_prefix": "0.0.0.0/0", "protocol": "tcp", "tenant_id": "341f49145ec7445192dc3c2abc33500d", "port_range_max": 65535, "security_group_id": "750acb9-d69b-4ea0-a62d-b56101166b01", "port_range_min": 1, "ethertype": "IPv4", "id": "fb6f2d5e-8290-4ed8-a23b-c6870813c921"}    |
   | tenant_id            | 607ec981611a4839b7b06f6dfa81317d                                                                                                                                                                                                                                                                                                       |
   +----------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

These rules are all "allow" type rules, as the default is deny. This
example shows the full port range for all protocols allowed from all
IPs. This section describes the most common security-group-rule
parameters:

direction
    The direction in which the security group rule is applied. Valid
    values are ``ingress`` or ``egress``.

remote_ip_prefix
    This attribute value matches the specified IP prefix as the source
    IP address of the IP packet.

protocol
    The protocol that is matched by the security group rule. Valid
    values are ``null``, ``tcp``, ``udp``, ``icmp``, and ``icmpv6``.

port_range_min
    The minimum port number in the range that is matched by the security
    group rule. If the protocol is TCP or UDP, this value must be less
    than or equal to the ``port_range_max`` attribute value. If the
    protocol is ICMP or ICMPv6, this value must be an ICMP or ICMPv6
    type, respectively.

port_range_max
    The maximum port number in the range that is matched by the security
    group rule. The ``port_range_min`` attribute constrains the
    ``port_range_max`` attribute. If the protocol is ICMP or ICMPv6,
    this value must be an ICMP or ICMPv6 type, respectively.

ethertype
    Must be ``IPv4`` or ``IPv6``, and addresses represented in CIDR must
    match the ingress or egress rules.

When adding a new security group, you should pick a descriptive but
brief name. This name shows up in brief descriptions of the instances
that use it where the longer description field often does not. Seeing
that an instance is using security group ``http`` is much easier to
understand than ``bobs_group`` or ``secgrp1``.

This example creates a security group that allows web traffic anywhere
on the Internet. We'll call this group ``global_http``, which is clear
and reasonably concise, encapsulating what is allowed and from where.
From the command line, do:

.. code-block:: console

   $ neutron security-group-create \
            global_http --description "allow web traffic from the Internet"
   Created a new security_group:
   +----------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
   | Field                | Value                                                                                                                                                                                                                                                                                                                         |
   +----------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
   | description          | allow web traffic from the Internet                                                                                                                                                                                                                                                                                           |
   | id                   | c6d78d56-7c56-4c82-abcb-05aa9839d1e7                                                                                                                                                                                                                                                                                          |
   | name                 | global_http                                                                                                                                                                                                                                                                                                                   |
   | security_group_rules | {"remote_group_id": null, "direction": "egress", "remote_ip_prefix": null, "protocol": null, "tenant_id": "341f49145ec7445192dc3c2abc33500d", "port_range_max": null, "security_group_id": "c6d78d56-7c56-4c82-abcb-05aa9839d1e7", "port_range_min": null, "ethertype": "IPv4", "id": "b2e56b3a-890b-48d3-9380-8a9f6f8b1b36"} |
   |                      | {"remote_group_id": null, "direction": "egress", "remote_ip_prefix": null, "protocol": null, "tenant_id": "341f49145ec7445192dc3c2abc33500d", "port_range_max": null, "security_group_id": "c6d78d56-7c56-4c82-abcb-05aa9839d1e7", "port_range_min": null, "ethertype": "IPv6", "id": "153d84ba-651d-45fd-9015-58807749efc5"} |
   | tenant_id            | 341f49145ec7445192dc3c2abc33500d                                                                                                                                                                                                                                                                                              |
   +----------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

Immediately after create, the security group has only an allow egress
rule. To make it do what we want, we need to add some rules:

.. code-block:: console

   $ neutron security-group-rule-create [-h]
                                        [-f {html,json,json,shell,table,value,yaml,yaml}]
                                        [-c COLUMN] [--max-width <integer>]
                                        [--noindent] [--prefix PREFIX]
                                        [--request-format {json,xml}]
                                        [--tenant-id TENANT_ID]
                                        [--direction {ingress,egress}]
                                        [--ethertype ETHERTYPE]
                                        [--protocol PROTOCOL]
                                        [--port-range-min PORT_RANGE_MIN]
                                        [--port-range-max PORT_RANGE_MAX]
                                        [--remote-ip-prefix REMOTE_IP_PREFIX]
                                        [--remote-group-id REMOTE_GROUP]
                                        SECURITY_GROUP
   $ neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol tcp --port-range-min 80 --port-range-max 80 --remote-ip-prefix 0.0.0.0/0 global_http
   Created a new security_group_rule:
   +-------------------+--------------------------------------+
   | Field             | Value                                |
   +-------------------+--------------------------------------+
   | direction         | ingress                              |
   | ethertype         | IPv4                                 |
   | id                | 88ec4762-239e-492b-8583-e480e9734622 |
   | port_range_max    | 80                                   |
   | port_range_min    | 80                                   |
   | protocol          | tcp                                  |
   | remote_group_id   |                                      |
   | remote_ip_prefix  | 0.0.0.0/0                            |
   | security_group_id | c6d78d56-7c56-4c82-abcb-05aa9839d1e7 |
   | tenant_id         | 341f49145ec7445192dc3c2abc33500d     |
   +-------------------+--------------------------------------+

More complex rule sets can be built up through multiple invocations of
:command:`neutron security-group-rule-create`. For example, if you want to pass
both http and https traffic, do this:

.. code-block:: console

   $ neutron security-group-rule-create --direction ingress --ethertype ipv4 --protocol tcp --port-range-min 443 --port-range-max 443 --remote-ip-prefix 0.0.0.0/0 global_http
   Created a new security_group_rule:
   +-------------------+--------------------------------------+
   | Field             | Value                                |
   +-------------------+--------------------------------------+
   | direction         | ingress                              |
   | ethertype         | IPv4                                 |
   | id                | c50315e5-29f3-408e-ae15-50fdc03fb9af |
   | port_range_max    | 443                                  |
   | port_range_min    | 443                                  |
   | protocol          | tcp                                  |
   | remote_group_id   |                                      |
   | remote_ip_prefix  | 0.0.0.0/0                            |
   | security_group_id | c6d78d56-7c56-4c82-abcb-05aa9839d1e7 |
   | tenant_id         | 341f49145ec7445192dc3c2abc33500d     |
   +-------------------+--------------------------------------+

Despite only outputting the newly added rule, this operation is
additive:

.. code-block:: console

   $ neutron security-group-show global_http
   +----------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
   | Field                | Value                                                                                                                                                                                                                                                                                                                                |
   +----------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
   | description          | allow web traffic from the Internet                                                                                                                                                                                                                                                                                                  |
   | id                   | c6d78d56-7c56-4c82-abcb-05aa9839d1e7                                                                                                                                                                                                                                                                                                 |
   | name                 | global_http                                                                                                                                                                                                                                                                                                                          |
   | security_group_rules | {"remote_group_id": null, "direction": "egress", "remote_ip_prefix": null, "protocol": null, "tenant_id": "341f49145ec7445192dc3c2abc33500d", "port_range_max": null, "security_group_id": "c6d78d56-7c56-4c82-abcb-05aa9839d1e7", "port_range_min": null, "ethertype": "IPv6", "id": "153d84ba-651d-45fd-9015-58807749efc5"}        |
   |                      | {"remote_group_id": null, "direction": "ingress", "remote_ip_prefix": "0.0.0.0/0", "protocol": "tcp", "tenant_id": "341f49145ec7445192dc3c2abc33500d", "port_range_max": 80, "security_group_id": "c6d78d56-7c56-4c82-abcb-05aa9839d1e7", "port_range_min": 80, "ethertype": "IPv4", "id": "88ec4762-239e-492b-8583-e480e9734622"}   |
   |                      | {"remote_group_id": null, "direction": "egress", "remote_ip_prefix": null, "protocol": null, "tenant_id": "341f49145ec7445192dc3c2abc33500d", "port_range_max": null, "security_group_id": "c6d78d56-7c56-4c82-abcb-05aa9839d1e7", "port_range_min": null, "ethertype": "IPv4", "id": "b2e56b3a-890b-48d3-9380-8a9f6f8b1b36"}        |
   |                      | {"remote_group_id": null, "direction": "ingress", "remote_ip_prefix": "0.0.0.0/0", "protocol": "tcp", "tenant_id": "341f49145ec7445192dc3c2abc33500d", "port_range_max": 443, "security_group_id": "c6d78d56-7c56-4c82-abcb-05aa9839d1e7", "port_range_min": 443, "ethertype": "IPv4", "id": "c50315e5-29f3-408e-ae15-50fdc03fb9af"} |
   | tenant_id            | 341f49145ec7445192dc3c2abc33500d                                                                                                                                                                                                                                                                                                     |
   +----------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

The inverse operation is called :command:`security-group-rule-delete`,
specifying security-group-rule ID. Whole security groups can be removed
with :command:`security-group-delete`.

To create security group rules for a cluster of instances, use
RemoteGroups.

RemoteGroups are a dynamic way of defining the CIDR of allowed sources.
The user specifies a RemoteGroup (security group name) and then all the
users' other instances using the specified RemoteGroup are selected
dynamically. This dynamic selection alleviates the need for individual
rules to allow each new member of the cluster.

The code is similar to the above example of
:command:`security-group-rule-create`. To use RemoteGroup, specify
:option:`--remote-group-id` instead of :option:`--remote-ip-prefix`.
For example:

.. code-block:: console

   $ neutron security-group-rule-create --direction ingress \
           --ethertype IPv4 --protocol tcp --port-range-min 22 --port-range-max 22 --remote-group-id global_http cluster

The "cluster" rule allows SSH access from any other instance that uses
the ``global-http`` group.

Block Storage
~~~~~~~~~~~~~

OpenStack volumes are persistent block-storage devices that may be
attached and detached from instances, but they can be attached to only
one instance at a time. Similar to an external hard drive, they do not
provide shared storage in the way a network file system or object store
does. It is left to the operating system in the instance to put a file
system on the block device and mount it, or not.

As with other removable disk technology, it is important that the
operating system is not trying to make use of the disk before removing
it. On Linux instances, this typically involves unmounting any file
systems mounted from the volume. The OpenStack volume service cannot
tell whether it is safe to remove volumes from an instance, so it does
what it is told. If a user tells the volume service to detach a volume
from an instance while it is being written to, you can expect some level
of file system corruption as well as faults from whatever process within
the instance was using the device.

There is nothing OpenStack-specific in being aware of the steps needed
to access block devices from within the instance operating system,
potentially formatting them for first use and being cautious when
removing them. What is specific is how to create new volumes and attach
and detach them from instances. These operations can all be done from
the **Volumes** page of the dashboard or by using the ``cinder``
command-line client.

To add new volumes, you need only a name and a volume size in gigabytes.
Either put these into the **create volume** web form or use the command
line:

.. code-block:: console

   $ cinder create --display-name test-volume 10

This creates a 10 GB volume named ``test-volume``. To list existing
volumes and the instances they are connected to, if any:

.. code-block:: console

   $ cinder list
   +------------+---------+--------------------+------+-------------+-------------+
   |     ID     | Status  |    Display Name    | Size | Volume Type | Attached to |
   +------------+---------+--------------------+------+-------------+-------------+
   | 0821...19f |  active |    test-volume     |  10  |     None    |             |
   +------------+---------+--------------------+------+-------------+-------------+

OpenStack Block Storage also allows creating snapshots of volumes.
Remember that this is a block-level snapshot that is crash consistent,
so it is best if the volume is not connected to an instance when the
snapshot is taken and second best if the volume is not in use on the
instance it is attached to. If the volume is under heavy use, the
snapshot may have an inconsistent file system. In fact, by default, the
volume service does not take a snapshot of a volume that is attached to
an image, though it can be forced to. To take a volume snapshot, either
select :guilabel:`Create Snapshot` from the :guilabel:`actions` column
next to the :guilabel:`volume` name on the **dashboard** volume page,
or run this from the command line:

.. code-block:: console

   usage: cinder snapshot-create [--force <True|False>]
   [--display-name <display-name>]
   [--display-description <display-description>]
   <volume-id>
   Add a new snapshot.
   Positional arguments:  <volume-id>         ID of the volume to snapshot
   Optional arguments:  --force <True|False>  Optional flag to indicate whether to
                                              snapshot a volume even if its
                                              attached to an instance.
                                              (Default=False)
   --display-name <display-name>              Optional snapshot name.
                                              (Default=None)
   --display-description <display-description>
   Optional snapshot description. (Default=None)

.. note::

   For more information about updating Block Storage volumes (for
   example, resizing or transferring), see the `OpenStack End User
   Guide <http://docs.openstack.org/user-guide/common/cli_manage_volumes.html>`__.

Block Storage Creation Failures
-------------------------------

If a user tries to create a volume and the volume immediately goes into
an error state, the best way to troubleshoot is to grep the cinder log
files for the volume's UUID. First try the log files on the cloud
controller, and then try the storage node where the volume was attempted
to be created:

.. code-block:: console

   # grep  903b85d0-bacc-4855-a261-10843fc2d65b /var/log/cinder/*.log

Shared File Systems Service
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Similar to Block Storage, the Shared File System is a persistent
storage, called share, that can be used in multi-tenant environments.
Users create and mount a share as a remote file system on any machine
that allows mounting shares, and has network access to share exporter.
This share can then be used for storing, sharing, and exchanging files.
The default configuration of the Shared File Systems service depends on
the back-end driver the admin chooses when starting the Shared File
Systems service. For more information about existing back-end drivers,
see section `"Share
Backends" <http://docs.openstack.org/developer/manila/devref/index.html#share-backends>`__
of Shared File Systems service Developer Guide. For example, in case of
OpenStack Block Storage based back-end is used, the Shared File Systems
service cares about everything, including VMs, networking, keypairs, and
security groups. Other configurations require more detailed knowledge of
shares functionality to set up and tune specific parameters and modes of
shares functioning.

Shares are a remote mountable file system, so users can mount a share to
multiple hosts, and have it accessed from multiple hosts by multiple
users at a time. With the Shared File Systems service, you can perform a
large number of operations with shares:

-  Create, update, delete, and force-delete shares

-  Change access rules for shares, reset share state

-  Specify quotas for existing users or tenants

-  Create share networks

-  Define new share types

-  Perform operations with share snapshots: create, change name, create
   a share from a snapshot, delete

-  Operate with consistency groups

-  Use security services

For more information on share management see section `“Share
management” <http://docs.openstack.org/admin-guide/shared_file_systems_share_management.html>`__
of chapter “Shared File Systems” in OpenStack Administrator Guide.
As to Security services, you should remember that different drivers
support different authentication methods, while generic driver does not
support Security Services at all (see section `“Security
services” <http://docs.openstack.org/admin-guide/shared_file_systems_security_services.html>`__
of chapter “Shared File Systems” in OpenStack Administrator Guide).

You can create a share in a network, list shares, and show information
for, update, and delete a specified share. You can also create snapshots
of shares (see section `“Share
snapshots” <http://docs.openstack.org/admin-guide/shared_file_systems_snapshots.html>`__
of chapter “Shared File Systems” in OpenStack Administrator Guide).

There are default and specific share types that allow you to filter or
choose back-ends before you create a share. Functions and behaviour of
share type is similar to Block Storage volume type (see section `“Share
types” <http://docs.openstack.org/admin-guide/shared_file_systems_share_types.html>`__
of chapter “Shared File Systems” in OpenStack Administrator Guide).

To help users keep and restore their data, Shared File Systems service
provides a mechanism to create and operate snapshots (see section
`“Share
snapshots” <http://docs.openstack.org/admin-guide/shared_file_systems_snapshots.html>`__
of chapter “Shared File Systems” in OpenStack Administrator Guide).

A security service stores configuration information for clients for
authentication and authorization. Inside Manila a share network can be
associated with up to three security types (for detailed information see
section `“Security
services” <http://docs.openstack.org/admin-guide/shared_file_systems_security_services.html>`__
of chapter “Shared File Systems” in OpenStack Administrator Guide):

-  LDAP

-  Kerberos

-  Microsoft Active Directory

Shared File Systems service differs from the principles implemented in
Block Storage. Shared File Systems service can work in two modes:

-  Without interaction with share networks, in so called "no share
   servers" mode.

-  Interacting with share networks.

Networking service is used by the Shared File Systems service to
directly operate with share servers. For switching interaction with
Networking service on, create a share specifying a share network. To use
"share servers" mode even being out of OpenStack, a network plugin
called StandaloneNetworkPlugin is used. In this case, provide network
information in the configuration: IP range, network type, and
segmentation ID. Also you can add security services to a share network
(see section
`“Networking” <http://docs.openstack.org/admin-guide/shared_file_systems_networking.html>`__
of chapter “Shared File Systems” in OpenStack Administrator Guide).


The main idea of consistency groups is to enable you to create snapshots
at the exact same point in time from multiple file system shares. Those
snapshots can be then used for restoring all shares that were associated
with the consistency group (see section `“Consistency
groups” <http://docs.openstack.org/admin-guide/shared_file_systems_cgroups.html>`__
of chapter “Shared File Systems” in OpenStack Administrator Guide).

Shared File System storage allows administrators to set limits and
quotas for specific tenants and users. Limits are the resource
limitations that are allowed for each tenant or user. Limits consist of:

-  Rate limits

-  Absolute limits

Rate limits control the frequency at which users can issue specific API
requests. Rate limits are configured by administrators in a config file.
Also, administrator can specify quotas also known as max values of
absolute limits per tenant. Whereas users can see only the amount of
their consumed resources. Administrator can specify rate limits or
quotas for the following resources:

-  Max amount of space awailable for all shares

-  Max number of shares

-  Max number of shared networks

-  Max number of share snapshots

-  Max total amount of all snapshots

-  Type and number of API calls that can be made in a specific time
   interval

User can see his rate limits and absolute limits by running commands
:command:`manila rate-limits` and :command:`manila absolute-limits`
respectively. For more details on limits and quotas see subsection `"Quotas
and limits" <http://docs.openstack.org/admin-guide/shared_file_systems_quotas.html>`__
of "Share management" section of OpenStack Administrator Guide document.

This section lists several of the most important Use Cases that
demonstrate the main functions and abilities of Shared File Systems
service:

-  Create share

-  Operating with a share

-  Manage access to shares

-  Create snapshots

-  Create a share network

-  Manage a share network

.. note::

   Shared File Systems service cannot warn you beforehand if it is safe
   to write a specific large amount of data onto a certain share or to
   remove a consistency group if it has a number of shares assigned to
   it. In such a potentially erroneous situations, if a mistake
   happens, you can expect some error message or even failing of shares
   or consistency groups into an incorrect status. You can also expect
   some level of system corruption if a user tries to unmount an
   unmanaged share while a process is using it for data transfer.


.. _create_share:

Create Share
------------

In this section, we examine the process of creating a simple share. It
consists of several steps:

-  Check if there is an appropriate share type defined in the Shared
   File Systems service

-  If such a share type does not exist, an Admin should create it using
   :command:`manila type-create` command before other users are able to use it

-  Using a share network is optional. However if you need one, check if
   there is an appropriate network defined in Shared File Systems
   service by using :command:`manila share-network-list` command. For the
   information on creating a share network, see
   :ref:`create_a_share_network` below in this chapter.

-  Create a public share using :command:`manila create`.

-  Make sure that the share has been created successfully and is ready
   to use (check the share status and see the share export location)

Below is the same whole procedure described step by step and in more
detail.

.. note::

   Before you start, make sure that Shared File Systems service is
   installed on your OpenStack cluster and is ready to use.

By default, there are no share types defined in Shared File Systems
service, so you can check if a required one has been already created:

.. code-block:: console

   $ manila type-list
   +------+--------+-----------+-----------+----------------------------------+----------------------+
   | ID   | Name   | Visibility| is_default| required_extra_specs             | optional_extra_specs |
   +------+--------+-----------+-----------+----------------------------------+----------------------+
   | c0...| default| public    | YES       | driver_handles_share_servers:True| snapshot_support:True|
   +------+--------+-----------+-----------+----------------------------------+----------------------+

If the share types list is empty or does not contain a type you need,
create the required share type using this command:

.. code-block:: console

   $ manila type-create netapp1 False --is_public True

This command will create a public share with the following parameters:
``name = netapp1``, ``spec_driver_handles_share_servers = False``

You can now create a public share with my_share_net network, default
share type, NFS shared file systems protocol, and 1 GB size:

.. code-block:: console

   $ manila create nfs 1 --name "Share1" --description "My first share" --share-type default --share-network my_share_net --metadata aim=testing --public
   +-----------------------------+--------------------------------------+
   | Property                    | Value                                |
   +-----------------------------+--------------------------------------+
   | status                      | creating                             |
   | share_type_name             | default                              |
   | description                 | My first share                       |
   | availability_zone           | None                                 |
   | share_network_id            | 9c187d23-7e1d-4d91-92d0-77ea4b9b9496 |
   | share_server_id             | None                                 |
   | host                        |                                      |
   | access_rules_status         | active                               |
   | snapshot_id                 | None                                 |
   | is_public                   | True                                 |
   | task_state                  | None                                 |
   | snapshot_support            | True                                 |
   | id                          | edd82179-587e-4a87-9601-f34b2ca47e5b |
   | size                        | 1                                    |
   | name                        | Share1                               |
   | share_type                  | e031d5e9-f113-491a-843f-607128a5c649 |
   | has_replicas                | False                                |
   | replication_type            | None                                 |
   | created_at                  | 2016-03-20T00:00:00.000000           |
   | share_proto                 | NFS                                  |
   | consistency_group_id        | None                                 |
   | source_cgsnapshot_member_id | None                                 |
   | project_id                  | e81908b1bfe8468abb4791eae0ef6dd9     |
   | metadata                    | {u'aim': u'testing'}                 |
   +-----------------------------+--------------------------------------+

To confirm that creation has been successful, see the share in the share
list:

.. code-block:: console

   $ manila list
   +----+-------+-----+------------+-----------+-------------------------------+----------------------+
   | ID | Name  | Size| Share Proto| Share Type| Export location               | Host                 |
   +----+-------+-----+------------+-----------+-------------------------------+----------------------+
   | a..| Share1| 1   | NFS        | c0086...  | 10.254.0.3:/shares/share-2d5..| manila@generic1#GEN..|
   +----+-------+-----+------------+-----------+-------------------------------+----------------------+

Check the share status and see the share export location. After
creation, the share status should become ``available``:

.. code-block:: console

   $ manila show Share1
   +-----------------------------+----------------------------------------------------------------------+
   | Property                    | Value                                                                |
   +-----------------------------+----------------------------------------------------------------------+
   | status                      | available                                                            |
   | share_type_name             | default                                                              |
   | description                 | My first share                                                       |
   | availability_zone           | nova                                                                 |
   | share_network_id            | 9c187d23-7e1d-4d91-92d0-77ea4b9b9496                                 |
   | export_locations            |                                                                      |
   |                             | path = 10.254.0.3:/shares/share-18cb05be-eb69-4cb2-810f-91c75ef30f90 |
   |                             | preferred = False                                                    |
   |                             | is_admin_only = False                                                |
   |                             | id = d6a82c0d-36b0-438b-bf34-63f3932ddf4e                            |
   |                             | share_instance_id = 18cb05be-eb69-4cb2-810f-91c75ef30f90             |
   |                             | path = 10.0.0.3:/shares/share-18cb05be-eb69-4cb2-810f-91c75ef30f90   |
   |                             | preferred = False                                                    |
   |                             | is_admin_only = True                                                 |
   |                             | id = 51672666-06b8-4741-99ea-64f2286f52e2                            |
   |                             | share_instance_id = 18cb05be-eb69-4cb2-810f-91c75ef30f90             |
   | share_server_id             | ea8b3a93-ab41-475e-9df1-0f7d49b8fa54                                 |
   | host                        | manila@generic1#GENERIC1                                             |
   | access_rules_status         | active                                                               |
   | snapshot_id                 | None                                                                 |
   | is_public                   | True                                                                 |
   | task_state                  | None                                                                 |
   | snapshot_support            | True                                                                 |
   | id                          | e7364bcc-3821-49bf-82d6-0c9f0276d4ce                                 |
   | size                        | 1                                                                    |
   | name                        | Share1                                                               |
   | share_type                  | e031d5e9-f113-491a-843f-607128a5c649                                 |
   | has_replicas                | False                                                                |
   | replication_type            | None                                                                 |
   | created_at                  | 2016-03-20T00:00:00.000000                                           |
   | share_proto                 | NFS                                                                  |
   | consistency_group_id        | None                                                                 |
   | source_cgsnapshot_member_id | None                                                                 |
   | project_id                  | e81908b1bfe8468abb4791eae0ef6dd9                                     |
   | metadata                    | {u'aim': u'testing'}                                                 |
   +-----------------------------+----------------------------------------------------------------------+

The value ``is_public`` defines the level of visibility for the share:
whether other tenants can or cannot see the share. By default, the share
is private. Now you can mount the created share like a remote file
system and use it for your purposes.

.. note::

   See subsection `“Share
   Management” <http://docs.openstack.org/admin-guide/shared_file_systems_share_management.html>`__
   of “Shared File Systems” section of Administrator Guide
   document for the details on share management operations.

Manage Access To Shares
-----------------------

Currently, you have a share and would like to control access to this
share for other users. For this, you have to perform a number of steps
and operations. Before getting to manage access to the share, pay
attention to the following important parameters. To grant or deny access
to a share, specify one of these supported share access levels:

-  ``rw``: read and write (RW) access. This is the default value.

-  ``ro:`` read-only (RO) access.

Additionally, you should also specify one of these supported
authentication methods:

-  ``ip``: authenticates an instance through its IP address. A valid
   format is XX.XX.XX.XX orXX.XX.XX.XX/XX. For example 0.0.0.0/0.

-  ``cert``: authenticates an instance through a TLS certificate.
   Specify the TLS identity as the IDENTKEY. A valid value is any string
   up to 64 characters long in the common name (CN) of the certificate.
   The meaning of a string depends on its interpretation.

-  ``user``: authenticates by a specified user or group name. A valid
   value is an alphanumeric string that can contain some special
   characters and is from 4 to 32 characters long.

.. note::

   Do not mount a share without an access rule! This can lead to an
   exception.

Allow access to the share with IP access type and 10.254.0.4 IP address:

.. code-block:: console

   $ manila access-allow Share1 ip 10.254.0.4 --access-level rw
   +--------------+--------------------------------------+
   | Property     | Value                                |
   +--------------+--------------------------------------+
   | share_id     | 7bcd888b-681b-4836-ac9c-c3add4e62537 |
   | access_type  | ip                                   |
   | access_to    | 10.254.0.4                           |
   | access_level | rw                                   |
   | state        | new                                  |
   | id           | de715226-da00-4cfc-b1ab-c11f3393745e |
   +--------------+--------------------------------------+

Mount the Share:

.. code-block:: console

   $ sudo mount -v -t nfs 10.254.0.5:/shares/share-5789ddcf-35c9-4b64-a28a-7f6a4a574b6a /mnt/

Then check if the share mounted successfully and according to the
specified access rules:

.. code-block:: console

   $ manila access-list Share1
   +--------------------------------------+-------------+------------+--------------+--------+
   | id                                   | access type | access to  | access level | state  |
   +--------------------------------------+-------------+------------+--------------+--------+
   | 4f391c6b-fb4f-47f5-8b4b-88c5ec9d568a | user        | demo       | rw           | error  |
   | de715226-da00-4cfc-b1ab-c11f3393745e | ip          | 10.254.0.4 | rw           | active |
   +--------------------------------------+-------------+------------+--------------+--------+

.. note::

   Different share features are supported by different share drivers.
   In these examples there was used generic (Cinder as a back-end)
   driver that does not support ``user`` and ``cert`` authentication
   methods.

.. note::

   For the details of features supported by different drivers see
   section `“Manila share features support
   mapping” <http://docs.openstack.org/developer/manila/devref/share_back_ends_feature_support_mapping.html>`__
   of Manila Developer Guide document.

Manage Shares
-------------

There are several other useful operations you would perform when working
with shares.

Update Share
------------

To change the name of a share, or update its description, or level of
visibility for other tenants, use this command:

.. code-block:: console

   $ manila update Share1 --description "My first share. Updated" --is-public False

Check the attributes of the updated Share1:

.. code-block:: console

   $ manila show Share1
   +-----------------------------+----------------------------------------------------------------------+
   | Property                    | Value                                                                |
   +-----------------------------+----------------------------------------------------------------------+
   | status                      | available                                                            |
   | share_type_name             | default                                                              |
   | description                 | My first share. Updated                                              |
   | availability_zone           | nova                                                                 |
   | share_network_id            | 9c187d23-7e1d-4d91-92d0-77ea4b9b9496                                 |
   | export_locations            |                                                                      |
   |                             | path = 10.254.0.3:/shares/share-18cb05be-eb69-4cb2-810f-91c75ef30f90 |
   |                             | preferred = False                                                    |
   |                             | is_admin_only = False                                                |
   |                             | id = d6a82c0d-36b0-438b-bf34-63f3932ddf4e                            |
   |                             | share_instance_id = 18cb05be-eb69-4cb2-810f-91c75ef30f90             |
   |                             | path = 10.0.0.3:/shares/share-18cb05be-eb69-4cb2-810f-91c75ef30f90   |
   |                             | preferred = False                                                    |
   |                             | is_admin_only = True                                                 |
   |                             | id = 51672666-06b8-4741-99ea-64f2286f52e2                            |
   |                             | share_instance_id = 18cb05be-eb69-4cb2-810f-91c75ef30f90             |
   | share_server_id             | ea8b3a93-ab41-475e-9df1-0f7d49b8fa54                                 |
   | host                        | manila@generic1#GENERIC1                                             |
   | access_rules_status         | active                                                               |
   | snapshot_id                 | None                                                                 |
   | is_public                   | False                                                                |
   | task_state                  | None                                                                 |
   | snapshot_support            | True                                                                 |
   | id                          | e7364bcc-3821-49bf-82d6-0c9f0276d4ce                                 |
   | size                        | 1                                                                    |
   | name                        | Share1                                                               |
   | share_type                  | e031d5e9-f113-491a-843f-607128a5c649                                 |
   | has_replicas                | False                                                                |
   | replication_type            | None                                                                 |
   | created_at                  | 2016-03-20T00:00:00.000000                                           |
   | share_proto                 | NFS                                                                  |
   | consistency_group_id        | None                                                                 |
   | source_cgsnapshot_member_id | None                                                                 |
   | project_id                  | e81908b1bfe8468abb4791eae0ef6dd9                                     |
   | metadata                    | {u'aim': u'testing'}                                                 |
   +-----------------------------+----------------------------------------------------------------------+

Reset Share State
-----------------

Sometimes a share may appear and then hang in an erroneous or a
transitional state. Unprivileged users do not have the appropriate
access rights to correct this situation. However, having cloud
administrator's permissions, you can reset the share's state by using

.. code-block:: console

   $ manila reset-state [–state state] share_name

command to reset share state, where state indicates which state to
assign the share to. Options include:
``available, error, creating, deleting, error_deleting`` states.

After running

.. code-block:: console

   $ manila reset-state Share2 --state deleting

check the share's status:

.. code-block:: console

   $ manila show Share2
   +-----------------------------+-------------------------------------------+
   | Property                    | Value                                     |
   +-----------------------------+-------------------------------------------+
   | status                      | deleting                                  |
   | share_type_name             | default                                   |
   | description                 | share from a snapshot.                    |
   | availability_zone           | nova                                      |
   | share_network_id            | 5c3cbabb-f4da-465f-bc7f-fadbe047b85a      |
   | export_locations            | []                                        |
   | share_server_id             | 41b7829d-7f6b-4c96-aea5-d106c2959961      |
   | host                        | manila@generic1#GENERIC1                  |
   | snapshot_id                 | 962e8126-35c3-47bb-8c00-f0ee37f42ddd      |
   | is_public                   | False                                     |
   | task_state                  | None                                      |
   | snapshot_support            | True                                      |
   | id                          | b6b0617c-ea51-4450-848e-e7cff69238c7      |
   | size                        | 1                                         |
   | name                        | Share2                                    |
   | share_type                  | c0086582-30a6-4060-b096-a42ec9d66b86      |
   | created_at                  | 2015-09-25T06:25:50.000000                |
   | export_location             | 10.254.0.3:/shares/share-1dc2a471-3d47-...|
   | share_proto                 | NFS                                       |
   | consistency_group_id        | None                                      |
   | source_cgsnapshot_member_id | None                                      |
   | project_id                  | 20787a7ba11946adad976463b57d8a2f          |
   | metadata                    | {u'source': u'snapshot'}                  |
   +-----------------------------+-------------------------------------------+

Delete Share
------------

If you do not need a share any more, you can delete it using
:command:`manila delete share_name_or_ID` command like:

.. code-block:: console

   $ manila delete Share2

.. note::

   If you specified the consistency group while creating a share, you
   should provide the --consistency-group parameter to delete the
   share:

.. code-block:: console

   $ manila delete ba52454e-2ea3-47fa-a683-3176a01295e6 --consistency-group ffee08d9-c86c-45e5-861e-175c731daca2

Sometimes it appears that a share hangs in one of transitional states
(i.e.
``creating, deleting, managing, unmanaging, extending, and shrinking``).
In that case, to delete it, you need
:command:`manila force-delete share_name_or_ID` command and administrative
permissions to run it:

.. code-block:: console

   $ manila force-delete b6b0617c-ea51-4450-848e-e7cff69238c7

.. note::

   For more details and additional information about other cases,
   features, API commands etc, see subsection `“Share
   Management” <http://docs.openstack.org/admin-guide/shared_file_systems_share_management.html>`__
   of “Shared File Systems” section of Administrator Guide document.

Create Snapshots
----------------

The Shared File Systems service provides a mechanism of snapshots to
help users to restore their own data. To create a snapshot, use
:command:`manila snapshot-create` command like:

.. code-block:: console

   $ manila snapshot-create Share1 --name Snapshot1 --description "Snapshot of Share1"
   +-------------------+--------------------------------------+
   | Property          | Value                                |
   +-------------------+--------------------------------------+
   | status            | creating                             |
   | share_id          | e7364bcc-3821-49bf-82d6-0c9f0276d4ce |
   | description       | Snapshot of Share1                   |
   | created_at        | 2016-03-20T00:00:00.000000           |
   | share_proto       | NFS                                  |
   | provider_location | None                                 |
   | id                | a96cf025-92d1-4012-abdd-bb0f29e5aa8f |
   | size              | 1                                    |
   | share_size        | 1                                    |
   | name              | Snapshot1                            |
   +-------------------+--------------------------------------+

Then, if needed, update the name and description of the created
snapshot:

.. code-block:: console

   $ manila snapshot-rename Snapshot1 Snapshot_1 --description "Snapshot of Share1. Updated."

To make sure that the snapshot is available, run:

.. code-block:: console

   $ manila snapshot-show Snapshot1
   +-------------------+--------------------------------------+
   | Property          | Value                                |
   +-------------------+--------------------------------------+
   | status            | available                            |
   | share_id          | e7364bcc-3821-49bf-82d6-0c9f0276d4ce |
   | description       | Snapshot of Share1                   |
   | created_at        | 2016-03-30T10:53:19.000000           |
   | share_proto       | NFS                                  |
   | provider_location | 3ca7a3b2-9f9f-46af-906f-6a565bf8ee37 |
   | id                | a96cf025-92d1-4012-abdd-bb0f29e5aa8f |
   | size              | 1                                    |
   | share_size        | 1                                    |
   | name              | Snapshot1                            |
   +-------------------+--------------------------------------+

.. note::

   For more details and additional information on snapshots, see
   subsection `“Share
   Snapshots” <http://docs.openstack.org/admin-guide/shared_file_systems_snapshots.html>`__
   of “Shared File Systems” section of “Administrator Guide” document.


.. _create_a_share_network:

Create a Share Network
----------------------

To control a share network, Shared File Systems service requires
interaction with Networking service to manage share servers on its own.
If the selected driver runs in a mode that requires such kind of
interaction, you need to specify the share network when a share is
created. For the information on share creation,
see :ref:`create_share` earlier in this chapter. Initially, check
the existing share networks type list by:

.. code-block:: console

   $ manila share-network-list
   +--------------------------------------+--------------+
   | id                                   | name         |
   +--------------------------------------+--------------+
   +--------------------------------------+--------------+

If share network list is empty or does not contain a required network,
just create, for example, a share network with a private network and
subnetwork.

.. code-block:: console

   $ manila share-network-create --neutron-net-id 5ed5a854-21dc-4ed3-870a-117b7064eb21 --neutron-subnet-id 74dcfb5a-b4d7-4855-86f5-a669729428dc --name my_share_net --description "My first share network"
   +-------------------+--------------------------------------+
   | Property          | Value                                |
   +-------------------+--------------------------------------+
   | name              | my_share_net                         |
   | segmentation_id   | None                                 |
   | created_at        | 2015-09-24T12:06:32.602174           |
   | neutron_subnet_id | 74dcfb5a-b4d7-4855-86f5-a669729428dc |
   | updated_at        | None                                 |
   | network_type      | None                                 |
   | neutron_net_id    | 5ed5a854-21dc-4ed3-870a-117b7064eb21 |
   | ip_version        | None                                 |
   | nova_net_id       | None                                 |
   | cidr              | None                                 |
   | project_id        | 20787a7ba11946adad976463b57d8a2f     |
   | id                | 5c3cbabb-f4da-465f-bc7f-fadbe047b85a |
   | description       | My first share network               |
   +-------------------+--------------------------------------+

The ``segmentation_id``, ``cidr``, ``ip_version``, and ``network_type``
share network attributes are automatically set to the values determined
by the network provider.

Then check if the network became created by requesting the networks list
once again:

.. code-block:: console

   $ manila share-network-list
   +--------------------------------------+--------------+
   | id                                   | name         |
   +--------------------------------------+--------------+
   | 5c3cbabb-f4da-465f-bc7f-fadbe047b85a | my_share_net |
   +--------------------------------------+--------------+

Finally, to create a share that uses this share network, get to Create
Share use case described earlier in this chapter.

.. note::

   See subsection `“Share
   Networks” <http://docs.openstack.org/admin-guide/shared_file_systems_share_networks.html>`__
   of “Shared File Systems” section of Administrator Guide
   document for more details.

Manage a Share Network
----------------------

There is a pair of useful commands that help manipulate share networks.
To start, check the network list:

.. code-block:: console

   $ manila share-network-list
   +--------------------------------------+--------------+
   | id                                   | name         |
   +--------------------------------------+--------------+
   | 5c3cbabb-f4da-465f-bc7f-fadbe047b85a | my_share_net |
   +--------------------------------------+--------------+

If you configured the back-end with
``driver_handles_share_servers = True`` (with the share servers) and had
already some operations in the Shared File Systems service, you can see
``manila_service_network`` in the neutron list of networks. This network
was created by the share driver for internal usage.

.. code-block:: console

   $ neutron net-list
   +--------------+------------------------+------------------------------------+
   | id           | name                   | subnets                            |
   +--------------+------------------------+------------------------------------+
   | 3b5a629a-e...| manila_service_network | 4f366100-50... 10.254.0.0/28       |
   | bee7411d-d...| public                 | 884a6564-01... 2001:db8::/64       |
   |              |                        | e6da81fa-55... 172.24.4.0/24       |
   | 5ed5a854-2...| private                | 74dcfb5a-bd... 10.0.0.0/24         |
   |              |                        | cc297be2-51... fd7d:177d:a48b::/64 |
   +--------------+------------------------+------------------------------------+

You also can see detailed information about the share network including
``network_type, segmentation_id`` fields:

.. code-block:: console

   $ neutron net-show manila_service_network
   +---------------------------+--------------------------------------+
   | Field                     | Value                                |
   +---------------------------+--------------------------------------+
   | admin_state_up            | True                                 |
   | availability_zone_hints   |                                      |
   | availability_zones        | nova                                 |
   | created_at                | 2016-03-20T00:00:00                  |
   | description               |                                      |
   | id                        | ef5282ab-dbf9-4d47-91d4-b0cc9b164567 |
   | ipv4_address_scope        |                                      |
   | ipv6_address_scope        |                                      |
   | mtu                       | 1450                                 |
   | name                      | manila_service_network               |
   | port_security_enabled     | True                                 |
   | provider:network_type     | vxlan                                |
   | provider:physical_network |                                      |
   | provider:segmentation_id  | 1047                                 |
   | router:external           | False                                |
   | shared                    | False                                |
   | status                    | ACTIVE                               |
   | subnets                   | aba49c7d-c7eb-44b9-9c8f-f6112b05a2e0 |
   | tags                      |                                      |
   | tenant_id                 | f121b3ee03804266af2959e56671b24a     |
   | updated_at                | 2016-03-20T00:00:00                  |
   +---------------------------+--------------------------------------+

You also can add and remove the security services to the share network.

.. note::

   For details, see subsection `"Security
   Services" <http://docs.openstack.org/admin-guide/shared_file_systems_security_services.html>`__
   of “Shared File Systems” section of Administrator Guide document.

Instances
~~~~~~~~~

Instances are the running virtual machines within an OpenStack cloud.
This section deals with how to work with them and their underlying
images, their network properties, and how they are represented in the
database.

Starting Instances
------------------

To launch an instance, you need to select an image, a flavor, and a
name. The name needn't be unique, but your life will be simpler if it is
because many tools will use the name in place of the UUID so long as the
name is unique. You can start an instance from the dashboard from the
:guilabel:`Launch Instance` button on the **Instances page** or by selecting
the :guilabel:`Launch Instance action` next to an :guilabel:`image`
or :guilabel:`snapshot` on the **Images** page.

On the command line, do this:

.. code-block:: console

   $ nova boot --flavor <flavor> --image <image> <name>

There are a number of optional items that can be specified. You should
read the rest of this section before trying to start an instance, but
this is the base command that later details are layered upon.

To delete instances from the dashboard, select the
:guilabel:`Delete instance action` next to the
:guilabel:`instance` on the **Instances** page.

.. note::

   In releases prior to Mitaka, select the equivalent :guilabel:`Terminate
   instance` action.

From the command line, do this:

.. code-block:: console

   $ nova delete <instance-uuid>

It is important to note that powering off an instance does not terminate
it in the OpenStack sense.

Instance Boot Failures
----------------------

If an instance fails to start and immediately moves to an error state,
there are a few different ways to track down what has gone wrong. Some
of these can be done with normal user access, while others require
access to your log server or compute nodes.

The simplest reasons for nodes to fail to launch are quota violations or
the scheduler being unable to find a suitable compute node on which to
run the instance. In these cases, the error is apparent when you run a
:command:`nova show` on the faulted instance:

.. code-block:: console

   $ nova show test-instance

.. code-block:: console

   +------------------------+-----------------------------------------------------\
   | Property               | Value                                               /
   +------------------------+-----------------------------------------------------\
   | OS-DCF:diskConfig      | MANUAL                                              /
   | OS-EXT-STS:power_state | 0                                                   \
   | OS-EXT-STS:task_state  | None                                                /
   | OS-EXT-STS:vm_state    | error                                               \
   | accessIPv4             |                                                     /
   | accessIPv6             |                                                     \
   | config_drive           |                                                     /
   | created                | 2013-03-01T19:28:24Z                                \
   | fault                  | {u'message': u'NoValidHost', u'code': 500, u'created/
   | flavor                 | xxl.super (11)                                      \
   | hostId                 |                                                     /
   | id                     | 940f3b2f-bd74-45ad-bee7-eb0a7318aa84                \
   | image                  | quantal-test (65b4f432-7375-42b6-a9b8-7f654a1e676e) /
   | key_name               | None                                                \
   | metadata               | {}                                                  /
   | name                   | test-instance                                       \
   | security_groups        | [{u'name': u'default'}]                             /
   | status                 | ERROR                                               \
   | tenant_id              | 98333a1a28e746fa8c629c83a818ad57                    /
   | updated                | 2013-03-01T19:28:26Z                                \
   | user_id                | a1ef823458d24a68955fec6f3d390019                    /
   +------------------------+-----------------------------------------------------\


In this case, looking at the ``fault`` message shows ``NoValidHost``,
indicating that the scheduler was unable to match the instance
requirements.

If :command:`nova show` does not sufficiently explain the failure, searching
for the instance UUID in the ``nova-compute.log`` on the compute node it
was scheduled on or the ``nova-scheduler.log`` on your scheduler hosts
is a good place to start looking for lower-level problems.

Using :command:`nova show` as an admin user will show the compute node the
instance was scheduled on as ``hostId``. If the instance failed during
scheduling, this field is blank.

Using Instance-Specific Data
----------------------------

There are two main types of instance-specific data: metadata and user
data.

Instance metadata
-----------------

For Compute, instance metadata is a collection of key-value pairs
associated with an instance. Compute reads and writes to these key-value
pairs any time during the instance lifetime, from inside and outside the
instance, when the end user uses the Compute API to do so. However, you
cannot query the instance-associated key-value pairs with the metadata
service that is compatible with the Amazon EC2 metadata service.

For an example of instance metadata, users can generate and register SSH
keys using the :command:`nova` command:

.. code-block:: console

   $ nova keypair-add mykey > mykey.pem

This creates a key named ``mykey``, which you can associate with
instances. The file ``mykey.pem`` is the private key, which should be
saved to a secure location because it allows root access to instances
the ``mykey`` key is associated with.

Use this command to register an existing key with OpenStack:

.. code-block:: console

   $ nova keypair-add --pub-key mykey.pub mykey

.. note::

   You must have the matching private key to access instances
   associated with this key.

To associate a key with an instance on boot, add :option:`--key_name mykey` to
your command line. For example:

.. code-block:: console

   $ nova boot --image ubuntu-cloudimage --flavor 2 --key_name mykey myimage

When booting a server, you can also add arbitrary metadata so that you
can more easily identify it among other running instances. Use the
:option:`--meta` option with a key-value pair, where you can make up the
string for both the key and the value. For example, you could add a
description and also the creator of the server:

.. code-block:: console

   $ nova boot --image=test-image --flavor=1 \
     --meta description='Small test image' smallimage

When viewing the server information, you can see the metadata included
on the metadata line:

.. code-block:: console

   $ nova show smallimage
   +------------------------+-----------------------------------------+
   |     Property           |                   Value                 |
   +------------------------+-----------------------------------------+
   |   OS-DCF:diskConfig    |               MANUAL                    |
   | OS-EXT-STS:power_state |                 1                       |
   | OS-EXT-STS:task_state  |                None                     |
   |  OS-EXT-STS:vm_state   |               active                    |
   |    accessIPv4          |                                         |
   |    accessIPv6          |                                         |
   |      config_drive      |                                         |
   |     created            |            2012-05-16T20:48:23Z         |
   |      flavor            |              m1.small                   |
   |      hostId            |             de0...487                   |
   |        id              |             8ec...f915                  |
   |      image             |             natty-image                 |
   |     key_name           |                                         |
   |     metadata           | {u'description': u'Small test image'}   |
   |       name             |             smallimage                  |
   |    private network     |            172.16.101.11                |
   |     progress           |                 0                       |
   |     public network     |             10.4.113.11                 |
   |      status            |               ACTIVE                    |
   |    tenant_id           |             e83...482                   |
   |     updated            |            2012-05-16T20:48:35Z         |
   |     user_id            |          de3...0a9                      |
   +------------------------+-----------------------------------------+

Instance user data
------------------

The ``user-data`` key is a special key in the metadata service that
holds a file that cloud-aware applications within the guest instance can
access. For example,
`cloudinit <https://help.ubuntu.com/community/CloudInit>`__ is an open
source package from Ubuntu, but available in most distributions, that
handles early initialization of a cloud instance that makes use of this
user data.

This user data can be put in a file on your local system and then passed
in at instance creation with the flag
:option:`--user-data` ``<user-data-file>``.

For example

.. code-block:: console

   $ nova boot --image ubuntu-cloudimage --flavor 1 --user-data mydata.file mydatainstance

To understand the difference between user data and metadata, realize
that user data is created before an instance is started. User data is
accessible from within the instance when it is running. User data can be
used to store configuration, a script, or anything the tenant wants.

File injection
--------------

Arbitrary local files can also be placed into the instance file system
at creation time by using the :option:`--file` ``<dst-path=src-path>`` option.
You may store up to five files.

For example, let's say you have a special ``authorized_keys`` file named
special_authorized_keysfile that for some reason you want to put on
the instance instead of using the regular SSH key injection. In this
case, you can use the following command:

.. code-block:: console

   $ nova boot --image ubuntu-cloudimage --flavor 1  \
     --file /root/.ssh/authorized_keys=special_authorized_keysfile authkeyinstance

Associating Security Groups
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Security groups, as discussed earlier, are typically required to allow
network traffic to an instance, unless the default security group for a
project has been modified to be more permissive.

Adding security groups is typically done on instance boot. When
launching from the dashboard, you do this on the
:guilabel:`Access & Security` tab of the Launch Instance dialog.
When launching from the command line, append ``--security-groups``
with a comma-separated list of security groups.

It is also possible to add and remove security groups when an instance
is running. Currently this is only available through the command-line
tools. Here is an example:

.. code-block:: console

   $ nova add-secgroup <server> <securitygroup>

.. code-block:: console

   $ nova remove-secgroup <server> <securitygroup>

Floating IPs
~~~~~~~~~~~~

Where floating IPs are configured in a deployment, each project will
have a limited number of floating IPs controlled by a quota. However,
these need to be allocated to the project from the central pool prior to
their use—usually by the administrator of the project. To allocate a
floating IP to a project, use the :guilabel:`Allocate IP To Project` button
on the :guilabel:`Floating IPs` tab of the :guilabel:`Access & Security` page
of the dashboard. The command line can also be used:

.. code-block:: console

   $ nova floating-ip-create

Once allocated, a floating IP can be assigned to running instances from
the dashboard either by selecting :guilabel:`Associate Floating IP` from the
actions drop-down next to the :guilabel:`IP on the Floating IPs` tab of the
**Access & Security page** or by making this selection next to the instance
you want to associate it with on the Instances page. The inverse action,
Dissociate Floating IP, is available from the :guilabel:`Floating IPs` tab
of the **Access & Security** page and from the **Instances** page.

To associate or disassociate a floating IP with a server from the
command line, use the following commands:

.. code-block:: console

   $ nova add-floating-ip <server> <address>

.. code-block:: console

   $ nova remove-floating-ip <server> <address>

Attaching Block Storage
~~~~~~~~~~~~~~~~~~~~~~~

You can attach block storage to instances from the dashboard on the
Volumes page. Click the Manage Attachments action next to the volume you
want to attach.

To perform this action from command line, run the following command:

.. code-block:: console

   $ nova volume-attach <server> <volume> <device>

You can also specify block deviceblock device mapping at instance boot
time through the nova command-line client with this option set:

.. code-block:: console

   --block-device-mapping <dev-name=mapping>

The block device mapping format is
``<dev-name>=<id>:<type>:<size(GB)>:<delete-on-terminate>``,
where:

dev-name
    A device name where the volume is attached in the system at
    ``/dev/dev_name``

id
    The ID of the volume to boot from, as shown in the output of
    :command:`nova volume-list`

type
    Either ``snap``, which means that the volume was created from a
    snapshot, or anything other than ``snap`` (a blank string is valid).
    In the preceding example, the volume was not created from a
    snapshot, so we leave this field blank in our following example.

size (GB)
    The size of the volume in gigabytes. It is safe to leave this blank
    and have the Compute Service infer the size.

delete-on-terminate
    A boolean to indicate whether the volume should be deleted when the
    instance is terminated. True can be specified as ``True`` or ``1``.
    False can be specified as ``False`` or ``0``.

The following command will boot a new instance and attach a volume at
the same time. The volume of ID 13 will be attached as ``/dev/vdc``. It
is not a snapshot, does not specify a size, and will not be deleted when
the instance is terminated:

.. code-block:: console

   $ nova boot --image 4042220e-4f5e-4398-9054-39fbd75a5dd7 \
               --flavor 2 --key-name mykey --block-device-mapping vdc=13:::0 \
               boot-with-vol-test

If you have previously prepared block storage with a bootable file
system image, it is even possible to boot from persistent block storage.
The following command boots an image from the specified volume. It is
similar to the previous command, but the image is omitted and the volume
is now attached as ``/dev/vda``:

.. code-block:: console

   $ nova boot --flavor 2 --key-name mykey \
               --block-device-mapping vda=13:::0 boot-from-vol-test

Read more detailed instructions for launching an instance from a
bootable volume in the `OpenStack End User
Guide <http://docs.openstack.org/user-guide/cli_nova_launch_instance_from_volume.html>`__.

To boot normally from an image and attach block storage, map to a device
other than vda. You can find instructions for launching an instance and
attaching a volume to the instance and for copying the image to the
attached volume in the `OpenStack End User
Guide <http://docs.openstack.org/user-guide/dashboard_launch_instances.html>`__.

Taking Snapshots
~~~~~~~~~~~~~~~~

The OpenStack snapshot mechanism allows you to create new images from
running instances. This is very convenient for upgrading base images or
for taking a published image and customizing it for local use. To
snapshot a running instance to an image using the CLI, do this:

.. code-block:: console

   $ nova image-create <instance name or uuid> <name of new image>

The dashboard interface for snapshots can be confusing because the
snapshots and images are displayed in the **Images** page. However, an
instance snapshot *is* an image. The only difference between an image
that you upload directly to the Image Service and an image that you
create by snapshot is that an image created by snapshot has additional
properties in the glance database. These properties are found in the
``image_properties`` table and include:

.. list-table::
   :widths: 50 50
   :header-rows: 1

   * - Name
     - Value
   * - ``image_type``
     - snapshot
   * - ``instance_uuid``
     - <uuid of instance that was snapshotted>
   * - ``base_image_ref``
     - <uuid of original image of instance that was snapshotted>
   * - ``image_location``
     - snapshot

Live Snapshots
--------------

Live snapshots is a feature that allows users to snapshot the running
virtual machines without pausing them. These snapshots are simply
disk-only snapshots. Snapshotting an instance can now be performed with
no downtime (assuming QEMU 1.3+ and libvirt 1.0+ are used).

.. note::

   If you use libvirt version ``1.2.2``, you may experience
   intermittent problems with live snapshot creation.

   To effectively disable the libvirt live snapshotting, until the
   problem is resolved, add the below setting to nova.conf.

   .. code-block:: ini

      [workarounds]
          disable_libvirt_livesnapshot = True

**Ensuring Snapshots of Linux Guests Are Consistent**

The following section is from Sébastien Han's `“OpenStack: Perform
Consistent Snapshots” blog
entry <http://www.sebastien-han.fr/blog/2012/12/10/openstack-perform-consistent-snapshots/>`__.

A snapshot captures the state of the file system, but not the state of
the memory. Therefore, to ensure your snapshot contains the data that
you want, before your snapshot you need to ensure that:

-  Running programs have written their contents to disk

-  The file system does not have any "dirty" buffers: where programs
   have issued the command to write to disk, but the operating system
   has not yet done the write

To ensure that important services have written their contents to disk
(such as databases), we recommend that you read the documentation for
those applications to determine what commands to issue to have them sync
their contents to disk. If you are unsure how to do this, the safest
approach is to simply stop these running services normally.

To deal with the "dirty" buffer issue, we recommend using the sync
command before snapshotting:

.. code-block:: console

   # sync

Running ``sync`` writes dirty buffers (buffered blocks that have been
modified but not written yet to the disk block) to disk.

Just running ``sync`` is not enough to ensure that the file system is
consistent. We recommend that you use the ``fsfreeze`` tool, which halts
new access to the file system, and create a stable image on disk that is
suitable for snapshotting. The ``fsfreeze`` tool supports several file
systems, including ext3, ext4, and XFS. If your virtual machine instance
is running on Ubuntu, install the util-linux package to get
``fsfreeze``:

.. note::

   In the very common case where the underlying snapshot is done via
   LVM, the filesystem freeze is automatically handled by LVM.

.. code-block:: console

   # apt-get install util-linux

If your operating system doesn't have a version of ``fsfreeze``
available, you can use ``xfs_freeze`` instead, which is available on
Ubuntu in the xfsprogs package. Despite the "xfs" in the name,
xfs_freeze also works on ext3 and ext4 if you are using a Linux kernel
version 2.6.29 or greater, since it works at the virtual file system
(VFS) level starting at 2.6.29. The xfs_freeze version supports the
same command-line arguments as ``fsfreeze``.

Consider the example where you want to take a snapshot of a persistent
block storage volume, detected by the guest operating system as
``/dev/vdb`` and mounted on ``/mnt``. The fsfreeze command accepts two
arguments:

-f
    Freeze the system

-u
    Thaw (unfreeze) the system

To freeze the volume in preparation for snapshotting, you would do the
following, as root, inside the instance:

.. code-block:: console

   # fsfreeze -f /mnt

You *must mount the file system* before you run the :command:`fsfreeze`
command.

When the :command:`fsfreeze -f` command is issued, all ongoing transactions in
the file system are allowed to complete, new write system calls are
halted, and other calls that modify the file system are halted. Most
importantly, all dirty data, metadata, and log information are written
to disk.

Once the volume has been frozen, do not attempt to read from or write to
the volume, as these operations hang. The operating system stops every
I/O operation and any I/O attempts are delayed until the file system has
been unfrozen.

Once you have issued the :command:`fsfreeze` command, it is safe to perform
the snapshot. For example, if your instance was named ``mon-instance`` and
you wanted to snapshot it to an image named ``mon-snapshot``, you could
now run the following:

.. code-block:: console

   $ nova image-create mon-instance mon-snapshot

When the snapshot is done, you can thaw the file system with the
following command, as root, inside of the instance:

.. code-block:: console

   # fsfreeze -u /mnt

If you want to back up the root file system, you can't simply run the
preceding command because it will freeze the prompt. Instead, run the
following one-liner, as root, inside the instance:

.. code-block:: console

   # fsfreeze -f / && read x; fsfreeze -u /

After this command it is common practice to call :command:`nova image-create`
from your workstation, and once done press enter in your instance shell
to unfreeze it. Obviously you could automate this, but at least it will
let you properly synchronize.


**Ensuring Snapshots of Windows Guests Are Consistent**

Obtaining consistent snapshots of Windows VMs is conceptually similar to
obtaining consistent snapshots of Linux VMs, although it requires
additional utilities to coordinate with a Windows-only subsystem
designed to facilitate consistent backups.

Windows XP and later releases include a Volume Shadow Copy Service (VSS)
which provides a framework so that compliant applications can be
consistently backed up on a live filesystem. To use this framework, a
VSS requestor is run that signals to the VSS service that a consistent
backup is needed. The VSS service notifies compliant applications
(called VSS writers) to quiesce their data activity. The VSS service
then tells the copy provider to create a snapshot. Once the snapshot has
been made, the VSS service unfreezes VSS writers and normal I/O activity
resumes.

QEMU provides a guest agent that can be run in guests running on KVM
hypervisors. This guest agent, on Windows VMs, coordinates with the
Windows VSS service to facilitate a workflow which ensures consistent
snapshots. This feature requires at least QEMU 1.7. The relevant guest
agent commands are:

guest-file-flush
    Write out "dirty" buffers to disk, similar to the Linux ``sync``
    operation.

guest-fsfreeze
    Suspend I/O to the disks, similar to the Linux ``fsfreeze -f``
    operation.

guest-fsfreeze-thaw
    Resume I/O to the disks, similar to the Linux ``fsfreeze -u``
    operation.

To obtain snapshots of a Windows VM these commands can be scripted in
sequence: flush the filesystems, freeze the filesystems, snapshot the
filesystems, then unfreeze the filesystems. As with scripting similar
workflows against Linux VMs, care must be used when writing such a
script to ensure error handling is thorough and filesystems will not be
left in a frozen state.

Instances in the Database
~~~~~~~~~~~~~~~~~~~~~~~~~

While instance information is stored in a number of database tables, the
table you most likely need to look at in relation to user instances is
the instances table.

The instances table carries most of the information related to both
running and deleted instances. It has a bewildering array of fields; for
an exhaustive list, look at the database. These are the most useful
fields for operators looking to form queries:

-  The ``deleted`` field is set to ``1`` if the instance has been
   deleted and ``NULL`` if it has not been deleted. This field is
   important for excluding deleted instances from your queries.

-  The ``uuid`` field is the UUID of the instance and is used throughout
   other tables in the database as a foreign key. This ID is also
   reported in logs, the dashboard, and command-line tools to uniquely
   identify an instance.

-  A collection of foreign keys are available to find relations to the
   instance. The most useful of these — ``user_id`` and ``project_id``
   are the UUIDs of the user who launched the instance
   and the project it was launched in.

-  The ``host`` field tells which compute node is hosting the instance.

-  The ``hostname`` field holds the name of the instance when it is
   launched. The display-name is initially the same as hostname but can
   be reset using the nova rename command.

A number of time-related fields are useful for tracking when state
changes happened on an instance:

-  ``created_at``

-  ``updated_at``

-  ``deleted_at``

-  ``scheduled_at``

-  ``launched_at``

-  ``terminated_at``

Good Luck!
~~~~~~~~~~

This section was intended as a brief introduction to some of the most
useful of many OpenStack commands. For an exhaustive list, please refer
to the `Administrator Guide <http://docs.openstack.org/admin-guide/>`__.
We hope your users remain happy and recognize your hard work!
(For more hard work, turn the page to the next chapter, where we discuss
the system-facing operations: maintenance, failures and debugging.)
