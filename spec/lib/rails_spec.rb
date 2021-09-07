require_relative '../spec_helper'
RSpec.describe Dry::Helpers::Rails do
  # 1. В папке helpers не было ни одного файла
  it "in folder not exist func" do
    # Входные данные
    str = File.dirname(__FILE__ ).concat("/test_helper/test_1")
    # Вызов функции
    find_func = Dry::Helpers::Rails::find_all_equal_definitions_of_ruby_functions_in_helpers(str)
    # Ожидаемые результаты
    expect(find_func).to eq(nil)
  end

  # 2. В папке helpers были руби файлы, но не содержали повторяющихся функций
  it "no repeat func" do
    # Входные данные
    str = File.dirname(__FILE__ ).concat("/test_helper/test_2")
    # Выполнение фунции
    find_func = Dry::Helpers::Rails::find_all_equal_definitions_of_ruby_functions_in_helpers(str)
    # Проверка результатов
    expect(find_func).to eq(nil)
  end

  # 3. В папке helpers были руби файлы, в одном из файлов функция объявлялась 2 раза
  it "func repeat 2 times" do
    # Входные данные
    str = File.dirname(__FILE__ ).concat("/test_helper/test_3")
    # Выполнение функции
    find_func = Dry::Helpers::Rails::find_all_equal_definitions_of_ruby_functions_in_helpers(str)
    # Ожидаемые данные
    expected_res = ["----------------------------------
Found function override :
function name: helloWorld
path to file: #{File.dirname(__FILE__ )}/test_helper/test_3\\helpers\\existRepeat.rb
number of string: 1
path to file: #{File.dirname(__FILE__ )}/test_helper/test_3\\helpers\\existRepeat.rb
number of string: 4"]
    # Проверка результатов
    expected_res.each_index do |index|
      expect(expected_res[index] == find_func[index]).to eq(true)
    end
  end

  # 4. одна функция повторялась в разных файлах 3 раза
  # и еще одно повторение было закомментированно
  it "one of functions repeat 3 times in different times" do
    # Входные данные
    str = File.dirname(__FILE__ ).concat("/test_helper/test_4")
    # Выполнение функции
    find_func = Dry::Helpers::Rails::find_all_equal_definitions_of_ruby_functions_in_helpers(str)
    # Ожидаемые данные
    expected_res = ["----------------------------------
Found function override :
function name: helloWorld
path to file: #{File.dirname(__FILE__ )}/test_helper/test_4\\helpers\\otherDir\\anotherFolder\\file.rb
number of string: 1
path to file: #{File.dirname(__FILE__ )}/test_helper/test_4\\helpers\\otherDir\\anotherRubyFile.rb
number of string: 1
path to file: #{File.dirname(__FILE__ )}/test_helper/test_4\\helpers\\rubyFunc.rb
number of string: 6"]
    # Проверка результатов
    expected_res.each_index do |index|
      expect(expected_res[index] == find_func[index]).to eq(true)
    end
  end

  # 5. 3 разные функции повторяются
  it "three different functions repeat in different files" do
    # Входные данные
    str = File.dirname(__FILE__ ).concat("/test_helper/test_5")
    # Выполнение функции
    find_func = Dry::Helpers::Rails::find_all_equal_definitions_of_ruby_functions_in_helpers(str)
    # Ожидаемые данные
    expected_res = ["----------------------------------
Found function override :
function name: repeatFunc
path to file: #{File.dirname(__FILE__ )}/test_helper/test_5\\helpers\\firstFile.rb
number of string: 5
path to file: #{File.dirname(__FILE__ )}/test_helper/test_5\\helpers\\folder\\otherRub.rb
number of string: 1
path to file: #{File.dirname(__FILE__ )}/test_helper/test_5\\helpers\\folder\\rub.rb
number of string: 5","----------------------------------
Found function override :
function name: otherFunc
path to file: #{File.dirname(__FILE__ )}/test_helper/test_5\\helpers\\firstFile.rb
number of string: 1
path to file: #{File.dirname(__FILE__ )}/test_helper/test_5\\helpers\\folder\\rub.rb
number of string: 1",
                    "----------------------------------
Found function override :
function name: abc
path to file: #{File.dirname(__FILE__ )}/test_helper/test_5\\helpers\\firstFile.rb
number of string: 9
path to file: #{File.dirname(__FILE__ )}/test_helper/test_5\\helpers\\folder\\rub.rb
number of string: 10"]
    # Проверка результатов
    expected_res.each_index do |index|
      expect(expected_res[index] == find_func[index]).to eq(true)
    end
  end
end
