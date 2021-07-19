require "./lib/dry/helpers/rails/version"

module Dry
  module Helpers
      module Rails
      class Error < StandardError; end
      # Your code goes here...
      # Создание массива путей ко всем ruby файлам в определенной папке
      def Rails.createPathToRubyFiles(path)
        paths = []
        Dir.each_child(path) do |filename|
          cur_file = path + "\\#{filename}"
          if (Dir.exist?(cur_file))
            finded_files = createPathToRubyFiles(cur_file)
            finded_files.each { |findPath| paths.push(findPath) }
          end
          if (filename.end_with?(".rb"))
            paths.push(cur_file)
          end
        end
        paths
      end

      # вырезание подстроки из строки по индексам
      def Rails.cutSubstrFromStrByIndexes(string, startOfStr, endOfStr)
        result = String.new
        if (startOfStr > 0)
          result = string[0..(startOfStr - 1)]
        end
        if ((endOfStr + 1) < string.length)
          c = string[endOfStr + 1..string.length]
          result.concat(string[endOfStr + 1..string.length])
        end
        result
      end

      # Удаляет из кода на Ruby все комментарии и строковые константы
      def Rails.deleteCommentsAndStrConsts(code)
        i = 0
        # нахожусь ли в строковой константе
        in_str_const = false
        # в какой строковой константе нахожусь
        start_sim_of_str_const = ""
        while (i < code.length) # ОСНОВНОЙ ЦИКЛ ПРОХОДИТ ПОСТРОЧНО КОД
          j = 0
          cur_str_length = code[i].length
          start_of_str_const = 0

          while (j < cur_str_length) # ЦИКЛ ПРОХОДЯЩИЙ ВНУТРИ СТРОКИ
            if (in_str_const) # ЕСЛИ ВНУТРИ СТРОКОВОЙ КОНСТАНТЫ
              if (code[i][j].eql?('\\')) # экранированый символ?
                j += 2
              else
                # Ищу конец строковой константы
                if (code[i][j].eql?(start_sim_of_str_const))
                  in_str_const = false
                  code[i] = cutSubstrFromStrByIndexes(code[i],
                                                      start_of_str_const, j)
                  cur_str_length = code[i].length
                  j = start_of_str_const
                else
                  j += 1
                end
              end
            else # ЕСЛИ НЕ ВНУТРИ СТРОКОВОЙ КОНСТАНТЫ
              # проверка на многострочный комментарий
              if (j == 0 && code[i].start_with?("=begin"))
                until (code[i].start_with?("=end"))
                  code[i].clear
                  i += 1
                end
                code[i] = cutSubstrFromStrByIndexes(code[i], 0, 3)
                cur_str_length = code[i].length
              end

              # был встречен однострочный комментарий комментарий
              if (code[i][j] == "#")
                code[i] = cutSubstrFromStrByIndexes(code[i], j, cur_str_length)
                cur_str_length = code[i].length
                j = j - 1
              end

              if (code[i][j].eql?('"') || code[i][j].eql?('\''))
                start_sim_of_str_const = code[i][j]
                start_of_str_const = j
                in_str_const = true
                j += 1
              else
                j += 1
              end
            end
          end
          if (in_str_const) # Если до сих пор внутри строковой константы
            code[i] = cutSubstrFromStrByIndexes(code[i], start_of_str_const, cur_str_length)
          end
          i += 1
        end
        code
      end

      # Класс, который хранит инфу про определения функций
      class FunctionDefinition
        attr_accessor :func_name, :file_path, :num_of_str
        def initialize(name, file_path, num_of_str)
          # необходимы для сообщения
          @func_name = name # имя функции
          @file_path = file_path # путь к файлу где была найдена функция
          @num_of_str = num_of_str # номер строки
        end
        # Сравнение
        def isObjsEqual(other)
          other.func_name == self.func_name
        end
      end

      # Поиск всех функций и создание массива
      def Rails.create_list_of_def_func(file_path)
        # Массив строк прочитанных из файла
        code_array = []

        # Чтение файла
        File.open(file_path) do |review_file|
          code_array.concat(review_file.readlines)
        end

        # Удаление всего ненужного(комментарии и строковые константы) из кода
        code_array = deleteCommentsAndStrConsts(code_array)

        reg = Regexp.new(/^\s*def\s+([a-zA-Z]\w*[!?=]?)\s*([(]?)/)

        # Объекты, хранящие инфу про функцию
        functions_info = []
        i = 0
        code_array.each.with_index do |obj, index|
          if(obj.match?(reg))
            find = obj.match(reg)
            functions_info.append(
              FunctionDefinition.new(find[1], file_path, index)
            )
          end
        end
        functions_info
      end

      def Rails.findEqualDefinitionsOfFunctionsInRubyFiles
        # путь, до папки проекта
        current_path = Dir.pwd

        # путь до папки "helpers"
        current_path.concat("\\helpers")

        # если папки в helpers в проекте не существует
        unless Dir.exist?(current_path)
          raise "Dir not exist"
        end

        # поиск всех ruby файлов
        paths = createPathToRubyFiles(current_path)

        # Создание массива функций
        list_of_def = []
        paths.each do |path|
          # массив функций найденных в файле
          defs = create_list_of_def_func(path)
          # добавляю каждую функцию по отдельности
          defs.each { |one_def| list_of_def.append(one_def) }
        end

        # Сравнение объектов функций по именам
        i = 0
        j = 1
        error_msgs = []
        while (i < list_of_def.length)
          j = i + 1
          while (j < list_of_def.length)
            if (list_of_def[i].isObjsEqual(list_of_def[j]))
              error_msgs.append(" -----------------------------------------------------------------
Found function override :
function name: #{list_of_def[i].func_name}
path to file: #{list_of_def[i].file_path}
number of string: #{list_of_def[i].num_of_str}
path to file: #{list_of_def[j].file_path}
number of string: #{list_of_def[j].num_of_str}\n")
            end
            j += 1
          end
          i += 1
        end
        error_msgs
      end
    end
  end
end
