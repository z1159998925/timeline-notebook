import os
import uuid
from flask import Blueprint, request, jsonify, url_for, session, send_file, current_app
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from models import db, TimelineEntry, Comment, User, TimeCapsule
from datetime import datetime

main = Blueprint('main', __name__)

# 健康检查路由
@main.route('/', methods=['GET'])
@main.route('/health', methods=['GET'])
def health_check():
    """健康检查端点"""
    try:
        # 检查数据库连接
        db.session.execute('SELECT 1')
        return jsonify({
            'status': 'healthy',
            'message': 'Timeline Notebook API is running',
            'version': '1.0.0',
            'environment': current_app.config.get('FLASK_ENV', 'development')
        }), 200
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'message': f'Database connection failed: {str(e)}'
        }), 500

# 允许上传的文件类型
ALLOWED_EXTENSIONS = {'txt', 'pdf', 'png', 'jpg', 'jpeg', 'gif', 'mp4', 'avi', 'mov'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# 获取所有时光轴条目
@main.route('/api/timeline', methods=['GET'])
def get_timeline():
    entries = TimelineEntry.query.order_by(TimelineEntry.created_at.desc()).all()
    result = []
    for entry in entries:
        entry_data = {
            'id': entry.id,
            'title': entry.title,
            'content': entry.content,
            'created_at': entry.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'media_type': entry.media_type,
            'media_url': url_for('static', filename=f'uploads/{entry.media_path}') if entry.media_path else None
        }
        result.append(entry_data)
    return jsonify(result)

# 添加新的时光轴条目
@main.route('/api/timeline', methods=['POST'])
def add_timeline_entry():
    title = request.form.get('title')
    content = request.form.get('content')

    if not title:
        return jsonify({'message': '标题不能为空'}), 400

    new_entry = TimelineEntry(title=title, content=content)

    # 处理文件上传
    if 'media' in request.files:
        file = request.files['media']
        if file and allowed_file(file.filename):
            # 获取原始文件名和扩展名
            original_filename = file.filename
            file_ext = original_filename.rsplit('.', 1)[1].lower() if '.' in original_filename else ''
            
            # 使用UUID生成安全的文件名，保留原始扩展名
            unique_filename = f'timeline_{uuid.uuid4().hex}.{file_ext}'
            file_path = os.path.join(current_app.config.get('UPLOAD_FOLDER'), unique_filename)
            file.save(file_path)

            # 确定文件类型
            if file_ext in {'png', 'jpg', 'jpeg', 'gif'}:
                new_entry.media_type = 'image'
            elif file_ext in {'mp4', 'avi', 'mov'}:
                new_entry.media_type = 'video'
            else:
                new_entry.media_type = 'file'

            new_entry.media_path = unique_filename

    db.session.add(new_entry)
    db.session.commit()

    return jsonify({'message': '添加成功', 'id': new_entry.id}), 201

# 删除时光轴条目
@main.route('/api/timeline/<int:entry_id>', methods=['DELETE'])
def delete_timeline_entry(entry_id):
    # 检查是否为管理员
    if 'user_id' not in session or session['role'] != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403

    print(f'收到删除请求，条目ID: {entry_id}')
    entry = TimelineEntry.query.get_or_404(entry_id)

    # 如果有媒体文件，删除文件
    if entry.media_path:
        file_path = os.path.join(current_app.config.get('UPLOAD_FOLDER'), entry.media_path)
        if os.path.exists(file_path):
            os.remove(file_path)

    # 删除相关评论
    comments = Comment.query.filter_by(entry_id=entry_id).all()
    for comment in comments:
        db.session.delete(comment)

    db.session.delete(entry)
    db.session.commit()

    return jsonify({'message': '删除成功'}), 200

# 获取时光轴条目的评论
@main.route('/api/timeline/<int:entry_id>/comments', methods=['GET'])
def get_comments(entry_id):
    comments = Comment.query.filter_by(entry_id=entry_id).order_by(Comment.created_at.desc()).all()
    result = []
    for comment in comments:
        comment_data = {
            'id': comment.id,
            'content': comment.content,
            'created_at': comment.created_at.strftime('%Y-%m-%d %H:%M:%S')
        }
        result.append(comment_data)
    return jsonify(result)

# 点赞时光轴条目
@main.route('/api/timeline/<int:entry_id>/like', methods=['POST'])
def like_timeline_entry(entry_id):
    entry = TimelineEntry.query.get_or_404(entry_id)
    entry.likes += 1
    db.session.commit()
    return jsonify({'message': '点赞成功', 'likes': entry.likes}), 200

# 用户注册
@main.route('/api/register', methods=['POST'])
def register():
    username = request.json.get('username')
    password = request.json.get('password')
    role = request.json.get('role', 'user')  # 默认为普通用户

    if User.query.filter_by(username=username).first():
        return jsonify({'message': '用户名已存在'}), 400

    new_user = User(username=username, role=role)
    new_user.set_password(password)

    db.session.add(new_user)
    db.session.commit()

    return jsonify({'message': '注册成功'}), 201

# 用户登录
@main.route('/api/login', methods=['POST'])
def login():
    username = request.json.get('username')
    password = request.json.get('password')
    print(f'登录请求: 用户名={username}')

    user = User.query.filter_by(username=username).first()
    if user and user.check_password(password):
        session['user_id'] = user.id
        session['username'] = user.username
        session['role'] = user.role
        print(f'登录成功: 用户={username}, session={dict(session)}')
        return jsonify({
            'message': '登录成功',
            'user': {
                'id': user.id,
                'username': user.username,
                'role': user.role
            }
        }), 200
    else:
        print(f'登录失败: 用户名={username}, 密码错误')
        return jsonify({'message': '用户名或密码错误'}), 401

# 用户登出
@main.route('/api/logout', methods=['POST'])
def logout():
    session.clear()
    return jsonify({'message': '登出成功'}), 200

# 检查登录状态
@main.route('/api/login-status', methods=['GET'])
def login_status():
    if 'user_id' in session:
        return jsonify({
            'is_logged_in': True,
            'user': {
                'id': session['user_id'],
                'username': session['username'],
                'role': session['role']
            }
        }), 200
    else:
        return jsonify({'is_logged_in': False}), 200

# 添加评论到时光轴条目
@main.route('/api/timeline/<int:entry_id>/comments', methods=['POST'])
def add_comment(entry_id):
    content = request.json.get('content')
    if not content:
        return jsonify({'message': '评论内容不能为空'}), 400

    entry = TimelineEntry.query.get_or_404(entry_id)
    new_comment = Comment(content=content, entry_id=entry_id)
    db.session.add(new_comment)
    db.session.commit()

    return jsonify({
        'message': '评论成功',
        'comment': {
            'id': new_comment.id,
            'content': new_comment.content,
            'created_at': new_comment.created_at.strftime('%Y-%m-%d %H:%M:%S')
        }
    }), 201

# 测试会话路由
@main.route('/api/test-session', methods=['GET'])
def test_session():
    # 打印会话内容
    print('会话内容:', session)
    # 检查用户是否登录
    if 'user_id' in session:
        return jsonify({
            'is_logged_in': True,
            'user_id': session['user_id'],
            'username': session['username'],
            'role': session['role'],
            'session_id': request.cookies.get('session')
        }), 200
    else:
        return jsonify({
            'is_logged_in': False,
            'session_id': request.cookies.get('session')
        }), 200

# ==================== 时间胶囊相关API ====================

# 获取所有时间胶囊列表
@main.route('/api/time-capsules', methods=['GET'])
def get_time_capsules():
    capsules = TimeCapsule.query.order_by(TimeCapsule.created_at.desc()).all()
    result = []
    for capsule in capsules:
        capsule_data = {
            'id': capsule.id,
            'title': capsule.title,
            'created_at': capsule.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'unlock_date': capsule.unlock_date.strftime('%Y-%m-%d %H:%M:%S'),
            'question': capsule.question,
            'can_unlock': capsule.can_unlock(),
            'remaining_time': capsule.get_remaining_time(),
            'is_unlocked': capsule.is_unlocked,
            'media_type': capsule.media_type,
            'has_media': capsule.media_path is not None
        }
        result.append(capsule_data)
    return jsonify(result)

# 创建新的时间胶囊
@main.route('/api/time-capsules', methods=['POST'])
def create_time_capsule():
    from datetime import datetime
    
    try:
        print(f"收到创建时间胶囊请求，Content-Type: {request.content_type}")
        print(f"是否为JSON请求: {request.is_json}")
        print(f"请求文件: {list(request.files.keys())}")
        
        # 支持JSON和form-data两种格式
        if request.is_json:
            data = request.get_json()
            title = data.get('title')
            content = data.get('content')
            question = data.get('question')
            answer = data.get('answer')
            unlock_date_str = data.get('unlock_date')
        else:
            title = request.form.get('title')
            content = request.form.get('content')
            question = request.form.get('question')
            answer = request.form.get('answer')
            unlock_date_str = request.form.get('unlock_date')
        
        print(f"解析的数据: title={title}, question={question}, answer={answer}, unlock_date={unlock_date_str}")
        
        if not title:
            return jsonify({'message': '标题不能为空'}), 400
        if not question:
            return jsonify({'message': '问题不能为空'}), 400
        if not answer:
            return jsonify({'message': '答案不能为空'}), 400
        if not unlock_date_str:
            return jsonify({'message': '解锁日期不能为空'}), 400
        
        try:
            # 解析日期时间
            unlock_date = datetime.strptime(unlock_date_str, '%Y-%m-%dT%H:%M')
            if unlock_date <= datetime.now():
                return jsonify({'message': '解锁日期必须是未来时间'}), 400
        except ValueError:
            return jsonify({'message': '日期格式错误'}), 400
        
        new_capsule = TimeCapsule(
            title=title,
            content=content,
            unlock_date=unlock_date,
            question=question
        )
        new_capsule.set_answer(answer)
    
        # 处理文件上传（仅在form-data请求时）
        if not request.is_json and 'media' in request.files:
            file = request.files['media']
            print(f"上传的文件: {file.filename}, 大小: {file.content_length if hasattr(file, 'content_length') else '未知'}")
            
            if file and file.filename != '':
                if allowed_file(file.filename):
                    # 获取原始文件名和扩展名
                    original_filename = file.filename
                    file_ext = original_filename.rsplit('.', 1)[1].lower() if '.' in original_filename else ''
                    
                    # 使用UUID生成安全的文件名，保留原始扩展名
                    unique_filename = f'capsule_{uuid.uuid4().hex}.{file_ext}'
                    file_path = os.path.join(current_app.config.get('UPLOAD_FOLDER'), unique_filename)
                    
                    print(f"原始文件名: {original_filename}")
                    print(f"生成的安全文件名: {unique_filename}")
                    
                    print(f"保存文件到: {file_path}")
                    file.save(file_path)
                    
                    # 确定文件类型
                    if file_ext in {'png', 'jpg', 'jpeg', 'gif'}:
                        new_capsule.media_type = 'image'
                    elif file_ext in {'mp4', 'avi', 'mov'}:
                        new_capsule.media_type = 'video'
                    else:
                        new_capsule.media_type = 'file'
                    
                    new_capsule.media_path = unique_filename
                    print(f"文件上传成功: {unique_filename}, 类型: {new_capsule.media_type}")
                else:
                    print(f"文件类型不被允许: {file.filename}")
                    return jsonify({'message': '不支持的文件类型'}), 400
            else:
                print("没有选择文件或文件名为空")
        
        db.session.add(new_capsule)
        db.session.commit()
        
        print(f"时间胶囊创建成功，ID: {new_capsule.id}")
        return jsonify({'message': '时间胶囊创建成功', 'id': new_capsule.id}), 201
    
    except Exception as e:
        print(f"创建时间胶囊时发生错误: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'message': f'创建失败: {str(e)}'}), 500

# 尝试解锁时间胶囊
@main.route('/api/time-capsules/<int:capsule_id>/unlock', methods=['POST'])
def unlock_time_capsule(capsule_id):
    answer = request.json.get('answer')
    
    if not answer:
        return jsonify({'message': '答案不能为空'}), 400
    
    capsule = TimeCapsule.query.get_or_404(capsule_id)
    
    # 检查时间是否到达
    if not capsule.can_unlock():
        return jsonify({
            'message': '时间胶囊尚未到达解锁时间',
            'remaining_time': capsule.get_remaining_time()
        }), 403
    
    # 增加尝试次数
    capsule.unlock_attempts += 1
    
    # 验证答案
    if capsule.check_answer(answer):
        capsule.is_unlocked = True
        db.session.commit()
        
        # 返回胶囊内容
        capsule_data = {
            'id': capsule.id,
            'title': capsule.title,
            'content': capsule.content,
            'created_at': capsule.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'unlock_date': capsule.unlock_date.strftime('%Y-%m-%d %H:%M:%S'),
            'media_type': capsule.media_type,
            'media_url': url_for('static', filename=f'uploads/{capsule.media_path}') if capsule.media_path else None,
            'is_unlocked': True
        }
        
        return jsonify({
            'message': '解锁成功',
            'capsule': capsule_data
        }), 200
    else:
        db.session.commit()
        return jsonify({
            'message': '答案错误',
            'attempts': capsule.unlock_attempts
        }), 401

# 获取已解锁的时间胶囊详情
@main.route('/api/time-capsules/<int:capsule_id>', methods=['GET'])
def get_time_capsule_detail(capsule_id):
    capsule = TimeCapsule.query.get_or_404(capsule_id)
    
    # 只有已解锁的胶囊才能查看详情
    if not capsule.is_unlocked:
        return jsonify({'message': '时间胶囊尚未解锁'}), 403
    
    capsule_data = {
        'id': capsule.id,
        'title': capsule.title,
        'content': capsule.content,
        'created_at': capsule.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        'unlock_date': capsule.unlock_date.strftime('%Y-%m-%d %H:%M:%S'),
        'media_type': capsule.media_type,
        'media_url': url_for('static', filename=f'uploads/{capsule.media_path}') if capsule.media_path else None,
        'is_unlocked': True
    }
    
    return jsonify(capsule_data)

# 删除时间胶囊（管理员功能）
@main.route('/api/time-capsules/<int:capsule_id>', methods=['DELETE'])
def delete_time_capsule(capsule_id):
    # 检查是否为管理员
    if 'user_id' not in session or session['role'] != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    capsule = TimeCapsule.query.get_or_404(capsule_id)
    
    # 如果有媒体文件，删除文件
    if capsule.media_path:
        file_path = os.path.join(current_app.config.get('UPLOAD_FOLDER'), capsule.media_path)
        if os.path.exists(file_path):
            os.remove(file_path)
    
    db.session.delete(capsule)
    db.session.commit()
    
    return jsonify({'message': '时间胶囊删除成功'}), 200

# 修改时间胶囊密码（管理员功能）
@main.route('/api/time-capsules/<int:capsule_id>/password', methods=['PUT'])
def update_time_capsule_password(capsule_id):
    # 检查是否为管理员
    if 'user_id' not in session or session['role'] != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    data = request.get_json()
    new_answer = data.get('answer')
    
    if not new_answer:
        return jsonify({'message': '新答案不能为空'}), 400
    
    capsule = TimeCapsule.query.get_or_404(capsule_id)
    
    # 更新答案
    capsule.set_answer(new_answer)
    db.session.commit()
    
    return jsonify({'message': '时间胶囊密码修改成功'}), 200

# 获取用户数量（管理员功能）
@main.route('/api/admin/users/count', methods=['GET'])
def get_user_count():
    # 检查是否为管理员
    if 'user_id' not in session or session['role'] != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    user_count = User.query.count()
    return jsonify({'count': user_count}), 200

# 创建数据备份（管理员功能）
@main.route('/api/admin/backup', methods=['POST'])
def create_backup():
    # 检查是否为管理员
    if 'user_id' not in session or session['role'] != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        import json
        from datetime import datetime
        
        # 创建备份数据
        backup_data = {
            'created_at': datetime.now().isoformat(),
            'version': '1.0',
            'timeline_entries': [],
            'time_capsules': [],
            'users': [],
            'comments': []
        }
        
        # 备份时光轴条目
        entries = TimelineEntry.query.all()
        for entry in entries:
            entry_data = {
                'id': entry.id,
                'title': entry.title,
                'content': entry.content,
                'date': entry.date.isoformat(),
                'media_type': entry.media_type,
                'media_path': entry.media_path,
                'created_at': entry.created_at.isoformat()
            }
            backup_data['timeline_entries'].append(entry_data)
        
        # 备份时间胶囊
        capsules = TimeCapsule.query.all()
        for capsule in capsules:
            capsule_data = {
                'id': capsule.id,
                'title': capsule.title,
                'content': capsule.content,
                'unlock_date': capsule.unlock_date.isoformat(),
                'question': capsule.question,
                'answer_hash': capsule.answer_hash,
                'media_type': capsule.media_type,
                'media_path': capsule.media_path,
                'is_unlocked': capsule.is_unlocked,
                'unlock_attempts': capsule.unlock_attempts,
                'created_at': capsule.created_at.isoformat()
            }
            backup_data['time_capsules'].append(capsule_data)
        
        # 备份用户数据
        users = User.query.all()
        for user in users:
            user_data = {
                'id': user.id,
                'username': user.username,
                'password_hash': user.password_hash,
                'role': user.role,
                'created_at': user.created_at.isoformat()
            }
            backup_data['users'].append(user_data)
        
        # 备份评论数据
        comments = Comment.query.all()
        for comment in comments:
            comment_data = {
                'id': comment.id,
                'content': comment.content,
                'timeline_entry_id': comment.timeline_entry_id,
                'created_at': comment.created_at.isoformat()
            }
            backup_data['comments'].append(comment_data)
        
        # 生成备份文件名
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f'backup_{timestamp}.json'
        
        # 确保备份目录存在
        backup_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'backups')
        os.makedirs(backup_dir, exist_ok=True)
        
        # 保存备份文件
        backup_path = os.path.join(backup_dir, filename)
        with open(backup_path, 'w', encoding='utf-8') as f:
            json.dump(backup_data, f, ensure_ascii=False, indent=2)
        
        return jsonify({
            'message': '备份创建成功',
            'filename': filename,
            'download_url': url_for('main.download_backup', filename=filename)
        }), 200
        
    except Exception as e:
        print(f"创建备份时发生错误: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'message': f'创建备份失败: {str(e)}'}), 500

# 获取备份历史（管理员功能）
@main.route('/api/admin/backups', methods=['GET'])
def get_backup_history():
    # 检查是否为管理员
    if 'user_id' not in session or session['role'] != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        backup_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'backups')
        
        if not os.path.exists(backup_dir):
            return jsonify([]), 200
        
        backups = []
        for filename in os.listdir(backup_dir):
            if filename.endswith('.json') and filename.startswith('backup_'):
                file_path = os.path.join(backup_dir, filename)
                file_stat = os.stat(file_path)
                
                backup_info = {
                    'id': filename.replace('.json', ''),
                    'filename': filename,
                    'created_at': datetime.fromtimestamp(file_stat.st_ctime).isoformat(),
                    'size': file_stat.st_size
                }
                backups.append(backup_info)
        
        # 按创建时间倒序排列
        backups.sort(key=lambda x: x['created_at'], reverse=True)
        
        return jsonify(backups), 200
        
    except Exception as e:
        print(f"获取备份历史时发生错误: {str(e)}")
        return jsonify({'message': f'获取备份历史失败: {str(e)}'}), 500

# 下载备份文件（管理员功能）
@main.route('/api/admin/backups/<filename>/download', methods=['GET'])
def download_backup(filename):
    # 检查是否为管理员
    if 'user_id' not in session or session['role'] != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        backup_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'backups')
        file_path = os.path.join(backup_dir, filename)
        
        if not os.path.exists(file_path) or not filename.endswith('.json'):
            return jsonify({'message': '备份文件不存在'}), 404
        
        return send_file(file_path, as_attachment=True, download_name=filename)
        
    except Exception as e:
        print(f"下载备份文件时发生错误: {str(e)}")
        return jsonify({'message': f'下载失败: {str(e)}'}), 500

# 删除备份文件（管理员功能）
@main.route('/api/admin/backups/<backup_id>', methods=['DELETE'])
def delete_backup(backup_id):
    # 检查是否为管理员
    if 'user_id' not in session or session['role'] != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        backup_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'backups')
        filename = f'{backup_id}.json'
        file_path = os.path.join(backup_dir, filename)
        
        if not os.path.exists(file_path):
            return jsonify({'message': '备份文件不存在'}), 404
        
        os.remove(file_path)
        return jsonify({'message': '备份删除成功'}), 200
        
    except Exception as e:
        print(f"删除备份文件时发生错误: {str(e)}")
        return jsonify({'message': f'删除失败: {str(e)}'}), 500

# 从备份文件还原数据（管理员功能）
@main.route('/api/admin/restore', methods=['POST'])
def restore_from_backup():
    # 检查是否为管理员
    if 'user_id' not in session or session['role'] != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        if 'backup_file' not in request.files:
            return jsonify({'message': '没有上传备份文件'}), 400
        
        file = request.files['backup_file']
        if file.filename == '':
            return jsonify({'message': '没有选择文件'}), 400
        
        if not file.filename.endswith('.json'):
            return jsonify({'message': '请上传JSON格式的备份文件'}), 400
        
        # 读取备份数据
        import json
        backup_data = json.load(file)
        
        # 验证备份文件格式
        required_keys = ['timeline_entries', 'time_capsules', 'users', 'comments']
        if not all(key in backup_data for key in required_keys):
            return jsonify({'message': '备份文件格式不正确'}), 400
        
        # 开始还原过程
        # 清空现有数据
        Comment.query.delete()
        TimeCapsule.query.delete()
        TimelineEntry.query.delete()
        # 保留管理员用户，删除其他用户
        User.query.filter(User.role != 'admin').delete()
        
        # 还原时光轴条目
        for entry_data in backup_data['timeline_entries']:
            entry = TimelineEntry(
                title=entry_data['title'],
                content=entry_data['content'],
                date=datetime.fromisoformat(entry_data['date']),
                media_type=entry_data.get('media_type'),
                media_path=entry_data.get('media_path')
            )
            if 'created_at' in entry_data:
                entry.created_at = datetime.fromisoformat(entry_data['created_at'])
            db.session.add(entry)
        
        # 还原时间胶囊
        for capsule_data in backup_data['time_capsules']:
            capsule = TimeCapsule(
                title=capsule_data['title'],
                content=capsule_data['content'],
                unlock_date=datetime.fromisoformat(capsule_data['unlock_date']),
                question=capsule_data['question'],
                media_type=capsule_data.get('media_type'),
                media_path=capsule_data.get('media_path'),
                is_unlocked=capsule_data.get('is_unlocked', False),
                unlock_attempts=capsule_data.get('unlock_attempts', 0)
            )
            capsule.answer_hash = capsule_data['answer_hash']
            if 'created_at' in capsule_data:
                capsule.created_at = datetime.fromisoformat(capsule_data['created_at'])
            db.session.add(capsule)
        
        # 还原用户数据（跳过管理员用户）
        for user_data in backup_data['users']:
            if user_data['role'] != 'admin':  # 不覆盖管理员用户
                existing_user = User.query.filter_by(username=user_data['username']).first()
                if not existing_user:
                    user = User(
                        username=user_data['username'],
                        role=user_data['role']
                    )
                    user.password_hash = user_data['password_hash']
                    if 'created_at' in user_data:
                        user.created_at = datetime.fromisoformat(user_data['created_at'])
                    db.session.add(user)
        
        # 还原评论数据
        for comment_data in backup_data['comments']:
            comment = Comment(
                content=comment_data['content'],
                timeline_entry_id=comment_data['timeline_entry_id']
            )
            if 'created_at' in comment_data:
                comment.created_at = datetime.fromisoformat(comment_data['created_at'])
            db.session.add(comment)
        
        db.session.commit()
        
        return jsonify({'message': '数据还原成功'}), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"还原数据时发生错误: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'message': f'数据还原失败: {str(e)}'}), 500