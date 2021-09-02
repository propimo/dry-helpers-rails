require_relative "./rails/version"

module Dry
  module Helpers
    module Rails
      class Error < StandardError; end

      # регулярка для поиска объявлений функций
      REG = Regexp.new(/^\s*def\s+([a-zA-Z]\w*[!?=]?)\s*([(]?)/)

      # Создает массив путей до всех руби файлов находящихся в папке по данному пути
      def Rails.find_paths_to_all_ruby_files_in_folder(path)
        paths = []
        Dir.each_child(path) do |filename|
          cur_file = path + "\\#{filename}"
          if (Dir.exist?(cur_file)) # если текущий файл папка
            # вызов этой функции для новой директории
            finded_files = find_paths_to_all_ruby_files_in_folder(cur_file)
            # добавляю все найденные пути
            finded_files.each { |findPath| paths.push(findPath) }
          end
          if (filename.end_with?(".rb")) # проверка, что находится рубишный файл
            paths.push(cur_file)
          end
        end
        paths
      end

      # Возращает новую строку, с замененными на пробелы символами по индексам
      def Rails.delete_substr_from_string_by_indexes(str, startOfStr, endOfStr)
        copyOfStr = str.clone # копия строки
        # Ошибка если неправильные границы
        if (startOfStr < 0 || endOfStr < startOfStr || endOfStr > str.length)
          raise "Error: incorrect borders"
        end
        # Заменяю подстроку на пробелы
        copyOfStr[startOfStr..endOfStr] = " " * (endOfStr - startOfStr + 1)
        # Возвращаю измененную строку
        copyOfStr
      end

      # Заменяет все комментарие и строковые константы в руби коде на пробелы
      def Rails.delete_comments_and_str_consts_from_ruby_code(code)
        # нахожусь ли в строковой константе
        in_str_const = false
        # в какой строковой константе нахожусь
        start_sim_of_str_const = ""

        code.each_index do |i|
          # ОСНОВНОЙ ЦИКЛ ПРОХОДИТ ПОСТРОЧНО КОД
          start_of_str_const = 0 # начало строковой константы
          is_escaped_char = false # текущий символ является экранированым символом
          code[i].each_char.with_index do |cur_char, j|
            if (in_str_const) # ЕСЛИ ВНУТРИ СТРОКОВОЙ КОНСТАНТЫ
              if (is_escaped_char) # если текущий символ экранирован
                is_escaped_char = false
              else
                # если текущий символ не экранирован
                if (code[i][j].eql?('\\')) # проверяю будет ли след. символ экранированным
                  is_escaped_char = true
                else
                  # Ищу конец строковой константы
                  if (code[i][j].eql?(start_sim_of_str_const))
                    in_str_const = false
                    code[i] = delete_substr_from_string_by_indexes(code[i], start_of_str_const, j)
                  end
                end
              end
            else
              # ЕСЛИ НЕ ВНУТРИ СТРОКОВОЙ КОНСТАНТЫ
              # проверка на многострочный комментарий
              if (j == 0 && code[i].start_with?("=begin"))
                index = i
                until (code[index].start_with?("=end"))
                  code[index].clear
                  index += 1
                end
                code[index] = delete_substr_from_string_by_indexes(code[index], 0, 3)
              end

              # был встречен однострочный комментарий комментарий
              if (code[i][j] == "#")
                code[i] = delete_substr_from_string_by_indexes(code[i], j, code[i].length)
              end

              # проверка на начало строковой константы
              if (code[i][j].eql?('"') || code[i][j].eql?('\''))
                start_sim_of_str_const = code[i][j]
                start_of_str_const = j
                in_str_const = true
              end
            end
          end
          if (in_str_const) # Если до сих пор внутри строковой константы
            code[i] = delete_substr_from_string_by_indexes(code[i], start_of_str_const, code[i].length)
          end
        end
        code
      end

      # Класс, хранящий информацию про найденные функции
      class FunctionDefinition
        attr_accessor :func_name # имя функции
        attr_accessor :pos_in_file # позиция в файле(полный путь к файлу, номер строки)

        def initialize(name)
          # необходимы для сообщения
          @func_name = name # имя функции
          @pos_in_file = [] # хранит позицию в файле
        end

        # добавление новой позиции файла
        def addNewPosInFile(pos)
          @pos_in_file.append(pos)
        end

        # Сравнение
        def eql?(other)
          other.func_name == self.func_name
        end
      end

      # чтение из файла
      def Rails.read_from_file(file_path)
        code_from_file = []
        if (File.exist?(file_path)) # проверка существования файла
          File.open(file_path) do |review_file|
            code_from_file.concat(review_file.readlines)
          end
        end
        code_from_file
      end

      # Возвращает массив всех объявлений функций в руби файле
      # (не производится поиск дупликатов)
      def Rails.find_all_definitions_of_functions_in_ruby_file(file_path)
        # Массив строк прочитанных из файла
        code_array = []

        code_array = Rails.read_from_file(file_path)

        # Удаление всего ненужного(комментарии и строковые константы) из кода
        code_array = delete_comments_and_str_consts_from_ruby_code(code_array)

        # Объекты, хранящие инфу про функцию
        functions_info = []
        code_array.each.with_index do |obj, index|
          find = obj.match(REG)
          if (find) # если было найдено определение функции
            # инфа о найденной функции
            newDef = FunctionDefinition.new(find[1])
            newPos = [file_path, index + 1]
            # сохраняю найденную функцию
            newDef.addNewPosInFile(newPos)
            functions_info.append(newDef)
          end
        end
        functions_info
      end

      # находит все дубли функций во всех руби файлах,
      # которые находятся в папке и подпапках указанного пути
      # возвращает массив объектов содержащий инфу о функциях
      def Rails.find_all_duplicates_of_ruby_functions_in_folder(dir_path)
        # если папки в helpers в проекте не существует
        unless Dir.exist?(dir_path)
          raise "Dir not exist"
        end

        # поиск всех ruby файлов
        paths = find_paths_to_all_ruby_files_in_folder(dir_path)

        # массив уникальных функций
        list_of_def = []
        # массив дубликатов функций
        list_of_duplicates = []

        paths.each do |path|
          # для каждого найденного пути к руби файлу
          # массив определений функций найденных в файле
          finded_defs_in_file = find_all_definitions_of_functions_in_ruby_file(path)

          # для каждого определения проверяю не находил ли я еще такое же определение раньше
          finded_defs_in_file.each do |one_of_finds|
            # поиск дублей
            finded_match = list_of_def.find { |one_of_list| one_of_finds.eql?(one_of_list) }

            if (finded_match) # если дубль был найден
              # запоминаю проверка чтобы повторно не запомнить дубль
              if(finded_match.pos_in_file.length == 1)
                list_of_duplicates.append(finded_match) # запомнинаю что данная функция дубль
              end
              # добавляю позицию, где находиться начало объявления метода в запись о методе
              finded_match.addNewPosInFile(one_of_finds.pos_in_file[0])
            else
              list_of_def.append(one_of_finds)
            end
          end
        end
        list_of_duplicates
      end

      # Основная функция
      # находит все повторяющиеся функции в папке helpers,
      # которая должна находится в папке указанного пути
      # возвращает массив строк содержащий информацию о повторяющихся методах
      # для текущей задачи(dir = Dir.pwd)
      def Rails.find_all_equal_definitions_of_ruby_functions_in_helpers(dir)
        # путь, до папки проекта в котором должная находиться папка helpers
        current_path = dir.concat("\\helpers")

        # создание массива, который хранит инфу о функциях, найденных в папке
        list_of_duplicates = find_all_duplicates_of_ruby_functions_in_folder(current_path)

        error_msgs = []
        list_of_duplicates.each do |one_of_def|
          mes = "----------------------------------
Found function override :
function name: #{one_of_def.func_name}"
          one_of_def.pos_in_file.each do |pos|
            mes.concat("
path to file: #{pos[0]}
number of string: #{pos[1]}"
            )
          end
          error_msgs.append(mes)
        end
        if (error_msgs.empty?)
          return nil
        else
          return error_msgs
        end
      end

    end
  end
end
