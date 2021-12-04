module Imap::Backup
  class CLI::Local < Thor
    include Thor::Actions
    include CLI::Helpers

    desc "accounts", "List locally backed-up accounts"
    def accounts
      connections = Imap::Backup::Configuration::List.new
      connections.accounts.each { |a| puts a[:username] }
    end

    desc "folders EMAIL", "List account folders"
    def folders(email)
      connections = Imap::Backup::Configuration::List.new
      account = connections.accounts.find { |a| a[:username] == email }
      raise "#{email} is not a configured account" if !account

      account_connection = Imap::Backup::Account::Connection.new(account)
      account_connection.local_folders.each do |_s, f|
        puts %("#{f.name}")
      end
    end

    desc "list EMAIL FOLDER", "List emails in a folder"
    def list(email, folder_name)
      connections = Imap::Backup::Configuration::List.new
      account = connections.accounts.find { |a| a[:username] == email }
      raise "#{email} is not a configured account" if !account

      account_connection = Imap::Backup::Account::Connection.new(account)
      folder_serializer, folder = account_connection.local_folders.find do |(_s, f)|
        f.name == folder_name
      end
      raise "Folder '#{folder_name}' not found" if !folder_serializer

      max_subject = 60
      puts format("%-10<uid>s  %-#{max_subject}<subject>s - %<date>s", {uid: "UID", subject: "Subject", date: "Date"})
      puts "-" * (12 + max_subject + 28)

      uids = folder_serializer.uids

      folder_serializer.each_message(uids).map do |uid, message|
        m = {
          uid: uid,
          date: message.parsed.date.to_s,
          subject: message.parsed.subject || ""
        }
        if m[:subject].length > max_subject
          puts format("% 10<uid>u: %.#{max_subject - 3}<subject>s... - %<date>s", m)
        else
          puts format("% 10<uid>u: %-#{max_subject}<subject>s - %<date>s", m)
        end
      end
    end

    desc "show EMAIL FOLDER UID[,UID]", "Show one or more emails"
    long_desc <<~DESC
      Prints out the requested emails.
      If more than one UID is given, they are separated by a header indicating
      the UID.
    DESC
    def show(email, folder_name, uids)
      connections = Imap::Backup::Configuration::List.new
      account = connections.accounts.find { |a| a[:username] == email }
      raise "#{email} is not a configured account" if !account

      account_connection = Imap::Backup::Account::Connection.new(account)
      folder_serializer, _folder = account_connection.local_folders.find do |(_s, f)|
        f.name == folder_name
      end
      raise "Folder '#{folder_name}' not found" if !folder_serializer

      uid_list = uids.split(",")
      folder_serializer.each_message(uid_list).each do |uid, message|
        if uid_list.count > 1
          puts <<~HEADER
            #{"-" * 80}
            #{format("| UID: %-71s |", uid)}
            #{"-" * 80}
          HEADER
        end
        puts message.supplied_body
      end
    end
  end
end