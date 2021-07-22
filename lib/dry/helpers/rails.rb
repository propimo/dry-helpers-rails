require "./lib/dry/helpers/rails/version"

module Dry
  module Helpers
    module Rails
      class Error < StandardError; end
      # Your code goes here...
      # Создание массива путей ко всем ruby файлам в определенной папке
      def createPathToRubyFiles(path)
        paths = []
        Dir.each_child(path) do |filename|
          cur_file = path + "\\#{filename}"
          if (Dir.exist?(cur_file)) # если текущий файл папка
            # вызов этой функции для новой директории
            finded_files = createPathToRubyFiles(cur_file)
            # добавляю все найденные пути
            finded_files.each { |findPath| paths.push(findPath) }
          end
          if (filename.end_with?(".rb")) # проверка, что находится рубишный файл
            paths.push(cur_file)
          end
        end
        paths
      end

      # Заменяет подстроку в строке на пробелы (по индексам)
      def deleteSubstrFromStrByIndexes(str, startOfStr, endOfStr)
        copyOfStr = str.clone
        # Ошибка если неправильные границы
        if (startOfStr < 0 || endOfStr < startOfStr || endOfStr > str.length)
          raise "Error: incorrect borders"
        end
        # Заменяю подстроку на пробелы
        copyOfStr[startOfStr..endOfStr] = " " * (endOfStr - startOfStr + 1)
        # Возвращаю измененную строку
        copyOfStr
      end

      # Удаляет из кода на Ruby все комментарии и строковые константы
      def deleteCommentsAndStrConsts(code)
        # нахожусь ли в строковой константе
        in_str_const = false
        # в какой строковой константе нахожусь
        start_sim_of_str_const = ""
        code.each_index do |i| # ОСНОВНОЙ ЦИКЛ ПРОХОДИТ ПОСТРОЧНО КОД
          start_of_str_const = 0 # начало строковой константы
          is_escaped_char = false # текущий символ является экранированым символом
          code[i].each_char.with_index do |cur_char, j|
            if (in_str_const) # ЕСЛИ ВНУТРИ СТРОКОВОЙ КОНСТАНТЫ
              if (is_escaped_char) # если текущий символ экранирован
                is_escaped_char = false
              else # если текущий символ не экранирован
                if (code[i][j].eql?('\\')) # проверяю будет ли след. символ экранированным
                  is_escaped_char = true
                else
                  # Ищу конец строковой константы
                  if (code[i][j].eql?(start_sim_of_str_const))
                    in_str_const = false
                    code[i] = deleteSubstrFromStrByIndexes(code[i], start_of_str_const, j)
                  end
                end
              end
            else # ЕСЛИ НЕ ВНУТРИ СТРОКОВОЙ КОНСТАНТЫ
              # проверка на многострочный комментарий
              if (j == 0 && code[i].start_with?("=begin"))
                index = i
                until (code[index].start_with?("=end"))
                  code[index].clear
                  index += 1
                end
                code[index] = deleteSubstrFromStrByIndexes(code[index], 0, 3)
              end

              # был встречен однострочный комментарий комментарий
              if (code[i][j] == "#")
                code[i] = deleteSubstrFromStrByIndexes(code[i], j, code[i].length)
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
            code[i] = deleteSubstrFromStrByIndexes(code[i], start_of_str_const, code[i].length)
          end
        end
        code
      end

      # Класс, который будет хранить где находится позиция
      # определения функции и путь к файлу где она объявлена
      class PositionInFile
        attr_accessor :file_path, :num_of_str

        def initialize(file_path, num_of_str)
          @file_path = file_path
          @num_of_str = num_of_str
        end
      end

      # Класс, который хранит инфу про определения функций
      class FunctionDefinition
        attr_accessor :func_name, :pos_in_file

        def initialize(name)
          # необходимы для сообщения
          @func_name = name # имя функции
          @pos_in_file = [] # хранит PositionInFile
        end

        # добавление
        def addNewPosInFile(pos)
          @pos_in_file.append(pos)
        end

        # Сравнение
        def eql?(other)
          other.func_name == self.func_name
        end
      end

      # Поиск всех функций и создание массива объявлений функций для одного файла
      def create_list_of_def_func(file_path)
        # Массив строк прочитанных из файла
        code_array = []

        # Чтение файла
        File.open(file_path) do |review_file|
          code_array.concat(review_file.readlines)
        end

        # Удаление всего ненужного(комментарии и строковые константы) из кода
        code_array = deleteCommentsAndStrConsts(code_array)

        # регулярка для поиска объявлений функций
        reg = Regexp.new(/^\s*def\s+([a-zA-Z]\w*[!?=]?)\s*([(]?)/)

        # Объекты, хранящие инфу про функцию
        functions_info = []
        code_array.each.with_index do |obj, index|
          if (obj.match?(reg)) # если было найдено определение функции
            find = obj.match(reg)
            # инфа о найденной функции
            newDef = FunctionDefinition.new(find[1])
            newPos = PositionInFile.new(file_path, index)

            # поиск была ли уже найдена функция с текущим именем
            matchEqual = -1
            functions_info.each.with_index do |func_inf, index_of_func_info|
              if (func_inf.eql?(newDef))
                matchEqual = index_of_func_info
              end
            end
            if (matchEqual == -1) # если совпадений не было найдено
              newDef.addNewPosInFile(newPos)
              functions_info.append(newDef)
            else # если было найдено совпадение
              functions_info[matchEqual].addNewPosInFile(newPos)
            end
          end
        end
        functions_info
      end

      # Основная функция
      # dir = Dir.pwd
      def findEqualDefinitionsOfFunctionsInRubyFiles(dir)
        # путь, до папки проекта в котором должная находиться папка helpers
        current_path = dir.concat("\\helpers")

        # если папки в helpers в проекте не существует
        unless Dir.exist?(current_path)
          raise "Dir not exist"
        end

        # поиск всех ruby файлов
        paths = createPathToRubyFiles(current_path)

        # Создание массива функций
        list_of_def = []

        paths.each do |path| # для каждого найденного пути к руби файлу
          # массив определений функций найденных в файле
          finded_defs_in_file = create_list_of_def_func(path)

          # для каждого определения проверяю не находил ли я еще такое же определение раньше
          finded_defs_in_file.each do |one_of_finds|
            finded_match = -1
            list_of_def.each.with_index do |one_of_list, index|
              if (one_of_finds.eql?(one_of_list))
                finded_match = index
              end
            end
            if (finded_match == -1)
              list_of_def.append(one_of_finds)
            else
              positions = one_of_finds.pos_in_file
              positions.each do |pos|
                list_of_def[finded_match].addNewPosInFile(pos)
              end
            end
          end
        end

        # Сравнение объектов функций по именам

        error_msgs = []
        list_of_def.each do |one_of_def|
          if (one_of_def.pos_in_file.length > 1)
            mes = "----------------------------------
Found function override :
function name: #{one_of_def.func_name}"
            one_of_def.pos_in_file.each do |pos|
              mes.concat("
path to file: #{pos.file_path}
number of string: #{pos.num_of_str}"
              )
            end
            error_msgs.append(mes)
          end
        end
        error_msgs
      end

      #puts findEqualDefinitionsOfFunctionsInRubyFiles(Dir.pwd)
    end
  end
end
