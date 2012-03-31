require 'blix/server/zmq_server'
require 'openssl'
require 'digest/sha2'

module Blix
  module Server
    
    class CryptError < StandardError;end
    
    class CryptZmqServer < ZmqServer
      
      attr_accessor :crypt_key, :crypt_iv
      
      def self.create(parser,handler, opts={})
        phrase = opts[:passphrase] or raise CryptError,"invalid passphrase"
        raise CryptError,"passphrase must be at lease 8 characters" unless phrase.length > 7
        
        instance = super(parser,handler, opts)
        sha256             = Digest::SHA2.new(256)
        instance.crypt_key = sha256.digest(phrase)
        instance.crypt_iv  = opts[:crypt_iv] || "shheyhhs34gshjsdaf876834kikow"
        instance
      end
      
      def send_notification(data)
        cipher = OpenSSL::Cipher::AES.new(128, :CBC)
        cipher.encrypt
        cipher.key = crypt_key
        cipher.iv  = crypt_iv
        encrypted  = cipher.update(data) + cipher.final
        super(encrypted)
      end
      
      def do_handle(encrypted)
        decipher = OpenSSL::Cipher::AES.new(128, :CBC)
        decipher.decrypt
        decipher.key = crypt_key
        decipher.iv = crypt_iv
        
        begin
          data = decipher.update(encrypted) + decipher.final
        rescue Exception=>e
          error             = ResponseMessage.new
          error.set_error
          error.id          = nil
          error.code        = 100
          error.description = "security violation"
          error.method      = "not defined"
          log_error "security violation #{e}"
          #raise CryptError,"cannot decrypt data"
          return  parser.format_response(error)
        end
        
        response = super(data)
        # now encrypt the response
        cipher = OpenSSL::Cipher::AES.new(128, :CBC)
        cipher.encrypt
        cipher.key = crypt_key
        cipher.iv  = crypt_iv
        encrypted  = cipher.update(response) + cipher.final
        encrypted
      end
    end
  end
end
