import 'package:privacy_of_animal/bloc_helpers/bloc_provider.dart';
import 'package:privacy_of_animal/logics/validation/validator.dart';
import 'package:rxdart/rxdart.dart';

class ValidationBloc extends Object 
  with EmailValidator,PasswordValidator,NameValidator,AgeValidator,JobValidator implements BlocBase {

  final BehaviorSubject<String> _emailController = BehaviorSubject<String>();
  final BehaviorSubject<String> _passwordController = BehaviorSubject<String>();
  final BehaviorSubject<String> _nameController = BehaviorSubject<String>();
  final BehaviorSubject<int> _ageController = BehaviorSubject<int>(seedValue: null);
  final BehaviorSubject<String> _jobController = BehaviorSubject<String>(seedValue: null);  

  Function(String) get onEmailChanged => _emailController.sink.add;
  Function(String) get onPasswordChanged => _passwordController.sink.add;
  Function(String) get onNameChanged => _nameController.sink.add;

  onAgeSelected(int age) => _ageController.sink.add(age);
  onJobSelected(String job) => _jobController.sink.add(job);

  Stream<String> get email => _emailController.stream.transform(validateEmail);
  Stream<String> get password => _passwordController.stream.transform(validatePassword);
  Stream<String> get name => _nameController.stream.transform(validateName);
  Stream<int> get age => _ageController.stream.transform(validateAge);
  Stream<String> get job => _jobController.stream.transform(validateJob);


  Stream<bool> get loginValid => Observable.combineLatest2(email,password, (e,p) => true);

  Stream<bool> get signUpValid => 
    Observable.combineLatest5(email,password,name,age,job, (e,p,n,a,j) => true);

  @override
  void dispose() {
    _emailController.close();
    _passwordController.close();
    _nameController.close();
    _ageController.close();
    _jobController.close();
  }
}
