# in order to test blix we need an AMQP exchange running
# somwhere which we have access to
#
# the AMQP exchange is specified here

$EXCHANGE_HOST = "albatross"

# ensure that errors in threads raise an exception
Thread.abort_on_exception= true

$:<<'lib'
require 'blix'