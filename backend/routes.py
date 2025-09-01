import os
import uuid
from flask import Blueprint, request, jsonify, url_for, session, send_file, current_app
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from models import db, TimelineEntry, Comment, User, TimeCapsule, Message, MessageComment, MessageLike, MessageImage, KeywordFilter
from datetime import datetime

main = Blueprint('main', __name__)

# 健康检查路由
@main.route('/', methods=['GET'])
@main.route('/health', methods=['GET'])
@main.route('/api/health', methods=['GET'])
def health_check():
    """健康检查端点"""
    try:
        # 检查数据库连接
        from sqlalchemy import text
        db.session.execute(text('SELECT 1'))
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
            try:
                # 获取原始文件名和扩展名
                original_filename = file.filename
                file_ext = original_filename.rsplit('.', 1)[1].lower() if '.' in original_filename else ''
                
                # 使用UUID生成安全的文件名，保留原始扩展名
                unique_filename = f'timeline_{uuid.uuid4().hex}.{file_ext}'
                upload_folder = current_app.config.get('UPLOAD_FOLDER')
                
                # 确保上传目录存在
                if not os.path.exists(upload_folder):
                    os.makedirs(upload_folder, exist_ok=True)
                    os.chmod(upload_folder, 0o777)
                
                file_path = os.path.join(upload_folder, unique_filename)

                file.save(file_path)
                
                # 设置文件权限
                os.chmod(file_path, 0o666)

                # 确定文件类型
                if file_ext in {'png', 'jpg', 'jpeg', 'gif'}:
                    new_entry.media_type = 'image'
                elif file_ext in {'mp4', 'avi', 'mov'}:
                    new_entry.media_type = 'video'
                else:
                    new_entry.media_type = 'file'

                new_entry.media_path = unique_filename

            except Exception as e:

                return jsonify({'message': f'文件上传失败: {str(e)}'}), 500

    db.session.add(new_entry)
    db.session.commit()

    return jsonify({'message': '添加成功', 'id': new_entry.id}), 201

# 删除时光轴条目
@main.route('/api/timeline/<int:entry_id>', methods=['DELETE'])
def delete_timeline_entry(entry_id):
    # 检查是否为管理员
    if 'user_id' not in session or session['role'] != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403


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
    email = request.json.get('email')
    password = request.json.get('password')
    role = request.json.get('role', 'user')  # 默认为普通用户

    if not username or not email or not password:
        return jsonify({'message': '用户名、邮箱和密码不能为空'}), 400

    if User.query.filter_by(username=username).first():
        return jsonify({'message': '用户名已存在'}), 400
    
    if User.query.filter_by(email=email).first():
        return jsonify({'message': '邮箱已存在'}), 400

    new_user = User(username=username, email=email, role=role)
    new_user.set_password(password)

    db.session.add(new_user)
    db.session.commit()

    return jsonify({'message': '注册成功'}), 201

# 用户登录
@main.route('/api/login', methods=['POST'])
def login():
    username = request.json.get('username')
    password = request.json.get('password')


    user = User.query.filter_by(username=username).first()
    if user and user.check_password(password):
        session['user_id'] = user.id
        session['username'] = user.username
        session['role'] = user.role

        return jsonify({
            'message': '登录成功',
            'user': {
                'id': user.id,
                'username': user.username,
                'role': user.role
            }
        }), 200
    else:

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

# ==================== 用户相关API ====================

# 获取用户信息
@main.route('/api/user/profile', methods=['GET'])
def get_user_profile():
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    user = User.query.get_or_404(session['user_id'])
    return jsonify({
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'bio': user.bio,
        'avatar_url': user.get_avatar_url(),
        'role': user.role,
        'is_active': user.is_active,
        'created_at': user.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        'updated_at': user.updated_at.strftime('%Y-%m-%d %H:%M:%S')
    }), 200

# 更新用户信息
@main.route('/api/user/profile', methods=['PUT'])
def update_user_profile():
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    user = User.query.get_or_404(session['user_id'])
    data = request.get_json()
    
    # 更新允许修改的字段
    if 'username' in data:
        # 检查用户名是否已存在
        existing_user = User.query.filter_by(username=data['username']).first()
        if existing_user and existing_user.id != user.id:
            return jsonify({'message': '用户名已存在'}), 400
        user.username = data['username']
        session['username'] = data['username']  # 更新session
    
    if 'email' in data:
        user.email = data['email']
    
    if 'bio' in data:
        user.bio = data['bio']
    
    user.updated_at = datetime.now()
    db.session.commit()
    
    return jsonify({'message': '用户信息更新成功'}), 200

# 修改密码
@main.route('/api/user/password', methods=['PUT'])
def change_password():
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    user = User.query.get_or_404(session['user_id'])
    data = request.get_json()
    
    current_password = data.get('current_password')
    new_password = data.get('new_password')
    
    if not current_password or not new_password:
        return jsonify({'message': '当前密码和新密码不能为空'}), 400
    
    if not user.check_password(current_password):
        return jsonify({'message': '当前密码错误'}), 400
    
    user.set_password(new_password)
    user.updated_at = datetime.now()
    db.session.commit()
    
    return jsonify({'message': '密码修改成功'}), 200

# 上传头像
@main.route('/api/user/avatar', methods=['POST'])
def upload_avatar():
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    if 'avatar' not in request.files:
        return jsonify({'message': '没有选择文件'}), 400
    
    file = request.files['avatar']
    if file.filename == '':
        return jsonify({'message': '没有选择文件'}), 400
    
    if file and allowed_file(file.filename):
        # 只允许图片格式作为头像
        file_ext = file.filename.rsplit('.', 1)[1].lower()
        if file_ext not in {'png', 'jpg', 'jpeg', 'gif'}:
            return jsonify({'message': '头像只支持图片格式'}), 400
        
        try:
            # 生成唯一文件名
            unique_filename = f'avatar_{session["user_id"]}_{uuid.uuid4().hex}.{file_ext}'
            upload_folder = current_app.config.get('UPLOAD_FOLDER')
            
            # 确保上传目录存在
            if not os.path.exists(upload_folder):
                os.makedirs(upload_folder, exist_ok=True)
                os.chmod(upload_folder, 0o777)
            
            file_path = os.path.join(upload_folder, unique_filename)
            file.save(file_path)
            os.chmod(file_path, 0o666)
            
            # 更新用户头像URL
            user = User.query.get_or_404(session['user_id'])
            
            # 删除旧头像文件（如果存在）
            if user.avatar_url:
                old_filename = user.avatar_url.split('/')[-1]
                old_file_path = os.path.join(upload_folder, old_filename)
                if os.path.exists(old_file_path):
                    os.remove(old_file_path)
            
            user.avatar_url = url_for('static', filename=f'uploads/{unique_filename}')
            user.updated_at = datetime.now()
            db.session.commit()
            
            return jsonify({
                'message': '头像上传成功',
                'avatar_url': user.avatar_url
            }), 200
            
        except Exception as e:
            return jsonify({'message': f'头像上传失败: {str(e)}'}), 500
    
    return jsonify({'message': '不支持的文件格式'}), 400

# 生成默认头像
@main.route('/api/avatar/default/<letter>', methods=['GET'])
def generate_default_avatar(letter):
    """生成基于首字母的默认头像SVG"""
    from flask import Response
    import random
    
    # 确保只有一个字符且为字母
    letter = letter.upper()[:1] if letter.isalpha() else 'U'
    
    # 预定义的颜色方案
    colors = [
        '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
        '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
    ]
    
    # 根据字母选择颜色（保证同一字母总是同一颜色）
    color_index = ord(letter) % len(colors)
    bg_color = colors[color_index]
    
    # 生成SVG头像
    svg_content = f'''
<svg width="80" height="80" xmlns="http://www.w3.org/2000/svg">
  <circle cx="40" cy="40" r="40" fill="{bg_color}"/>
  <text x="40" y="50" font-family="Arial, sans-serif" font-size="32" font-weight="bold" 
        text-anchor="middle" fill="white">{letter}</text>
</svg>'''
    
    return Response(svg_content, mimetype='image/svg+xml')

# 获取用户统计数据
@main.route('/api/user/stats', methods=['GET'])
def get_user_stats():
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    user_id = session['user_id']
    
    # 统计用户的留言数量
    message_count = Message.query.filter_by(user_id=user_id).count()
    
    # 统计用户获得的点赞数量
    like_count = db.session.query(MessageLike).join(Message).filter(Message.user_id == user_id).count()
    
    # 统计用户的评论数量
    comment_count = MessageComment.query.filter_by(user_id=user_id).count()
    
    return jsonify({
        'message_count': message_count,
        'like_count': like_count,
        'comment_count': comment_count
    }), 200

# 获取用户的留言列表
@main.route('/api/user/messages', methods=['GET'])
def get_user_messages():
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    user_id = session['user_id']
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 10, type=int)
    
    messages = Message.query.filter_by(user_id=user_id).order_by(Message.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    result = []
    for message in messages.items:
        message_data = {
            'id': message.id,
            'content': message.content,
            'created_at': message.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'like_count': message.like_count,
            'comment_count': MessageComment.query.filter_by(message_id=message.id).count()
        }
        result.append(message_data)
    
    return jsonify({
        'messages': result,
        'total': messages.total,
        'pages': messages.pages,
        'current_page': page
    }), 200

# 获取用户的评论列表
@main.route('/api/user/comments', methods=['GET'])
def get_user_comments():
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    user_id = session['user_id']
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 10, type=int)
    
    comments = MessageComment.query.filter_by(user_id=user_id).order_by(MessageComment.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    result = []
    for comment in comments.items:
        message = Message.query.get(comment.message_id)
        comment_data = {
            'id': comment.id,
            'content': comment.content,
            'created_at': comment.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'message_id': comment.message_id,
            'message_content': message.content[:50] + '...' if message and len(message.content) > 50 else (message.content if message else '')
        }
        result.append(comment_data)
    
    return jsonify({
        'comments': result,
        'total': comments.total,
        'pages': comments.pages,
        'current_page': page
    }), 200

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

            
            if file and file.filename != '':
                if allowed_file(file.filename):
                    # 获取原始文件名和扩展名
                    original_filename = file.filename
                    file_ext = original_filename.rsplit('.', 1)[1].lower() if '.' in original_filename else ''
                    
                    # 使用UUID生成安全的文件名，保留原始扩展名
                    unique_filename = f'capsule_{uuid.uuid4().hex}.{file_ext}'
                    file_path = os.path.join(current_app.config.get('UPLOAD_FOLDER'), unique_filename)
                    

                    file.save(file_path)
                    
                    # 确定文件类型
                    if file_ext in {'png', 'jpg', 'jpeg', 'gif'}:
                        new_capsule.media_type = 'image'
                    elif file_ext in {'mp4', 'avi', 'mov'}:
                        new_capsule.media_type = 'video'
                    else:
                        new_capsule.media_type = 'file'
                    
                    new_capsule.media_path = unique_filename

                else:
                    return jsonify({'message': '不支持的文件类型'}), 400
            else:
                pass
        
        db.session.add(new_capsule)
        db.session.commit()
        

        return jsonify({'message': '时间胶囊创建成功', 'id': new_capsule.id}), 201
    
    except Exception as e:

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

        import traceback
        traceback.print_exc()
        return jsonify({'message': f'数据还原失败: {str(e)}'}), 500


# ==================== 留言墙相关API ====================

# 内容审核和关键词过滤函数
def filter_content(content):
    """检查内容是否包含敏感词汇"""
    if not content:
        return True, content
    
    # 获取所有活跃的关键词过滤规则
    filters = KeywordFilter.query.filter_by(is_active=True).all()
    
    for filter_rule in filters:
        if filter_rule.keyword.lower() in content.lower():
            return False, f"内容包含敏感词汇: {filter_rule.keyword}"
    
    return True, content

# 获取所有留言
@main.route('/api/messages', methods=['GET'])
def get_messages():
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 10, type=int)
    
    # 分页查询，置顶的留言优先显示
    messages = Message.query.filter_by(status='published').order_by(
        Message.is_pinned.desc(),
        Message.created_at.desc()
    ).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    result = []
    for message in messages.items:
        # 获取留言的图片
        images = [{
            'id': img.id,
            'url': url_for('static', filename=f'uploads/{img.image_url}'),
            'name': img.image_name
        } for img in message.images]
        
        message_data = {
            'id': message.id,
            'content': message.content,
            'is_pinned': message.is_pinned,
            'like_count': message.like_count,
            'comment_count': message.comment_count,
            'created_at': message.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'user': {
                'id': message.user.id,
                'username': message.user.username,
                'avatar_url': message.user.get_avatar_url()
            },
            'images': images
        }
        result.append(message_data)
    
    return jsonify({
        'messages': result,
        'pagination': {
            'page': messages.page,
            'pages': messages.pages,
            'per_page': messages.per_page,
            'total': messages.total,
            'has_next': messages.has_next,
            'has_prev': messages.has_prev
        }
    })

# 发布新留言
@main.route('/api/messages', methods=['POST'])
def create_message():
    # 检查用户是否登录
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    content = request.form.get('content')
    if not content:
        return jsonify({'message': '留言内容不能为空'}), 400
    
    # 内容审核
    is_valid, filter_result = filter_content(content)
    if not is_valid:
        return jsonify({'message': filter_result}), 400
    
    # 创建新留言
    new_message = Message(
        user_id=session['user_id'],
        content=content,
        status='published'
    )
    
    db.session.add(new_message)
    db.session.flush()  # 获取message的ID
    
    # 处理图片上传
    uploaded_images = []
    if 'images' in request.files:
        files = request.files.getlist('images')
        for file in files:
            if file and file.filename != '' and allowed_file(file.filename):
                try:
                    # 生成安全的文件名
                    original_filename = file.filename
                    file_ext = original_filename.rsplit('.', 1)[1].lower() if '.' in original_filename else ''
                    unique_filename = f'message_{uuid.uuid4().hex}.{file_ext}'
                    
                    upload_folder = current_app.config.get('UPLOAD_FOLDER')
                    if not os.path.exists(upload_folder):
                        os.makedirs(upload_folder, exist_ok=True)
                    
                    file_path = os.path.join(upload_folder, unique_filename)
                    file.save(file_path)
                    
                    # 保存图片信息到数据库
                    message_image = MessageImage(
                        message_id=new_message.id,
                        image_url=unique_filename,
                        image_name=original_filename,
                        file_size=os.path.getsize(file_path)
                    )
                    db.session.add(message_image)
                    uploaded_images.append({
                        'name': original_filename,
                        'url': url_for('static', filename=f'uploads/{unique_filename}')
                    })
                    
                except Exception as e:
    
                    continue
    
    db.session.commit()
    
    return jsonify({
        'message': '留言发布成功',
        'id': new_message.id,
        'uploaded_images': uploaded_images
    }), 201

# 删除留言
@main.route('/api/messages/<int:message_id>', methods=['DELETE'])
def delete_message(message_id):
    # 检查用户是否登录
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    message = Message.query.get_or_404(message_id)
    
    # 检查权限：只有留言作者或管理员可以删除
    if message.user_id != session['user_id'] and session.get('role') != 'admin':
        return jsonify({'message': '没有权限删除此留言'}), 403
    
    # 删除相关的图片文件
    for image in message.images:
        file_path = os.path.join(current_app.config.get('UPLOAD_FOLDER'), image.image_url)
        if os.path.exists(file_path):
            os.remove(file_path)
    
    db.session.delete(message)
    db.session.commit()
    
    return jsonify({'message': '留言删除成功'}), 200

# 置顶/取消置顶留言（管理员功能）
@main.route('/api/messages/<int:message_id>/pin', methods=['POST'])
def toggle_pin_message(message_id):
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    message = Message.query.get_or_404(message_id)
    message.is_pinned = not message.is_pinned
    db.session.commit()
    
    action = '置顶' if message.is_pinned else '取消置顶'
    return jsonify({'message': f'留言{action}成功', 'is_pinned': message.is_pinned}), 200

# 点赞/取消点赞留言
@main.route('/api/messages/<int:message_id>/like', methods=['POST'])
def toggle_like_message(message_id):
    # 检查用户是否登录
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    message = Message.query.get_or_404(message_id)
    user_id = session['user_id']
    
    # 检查用户是否已经点赞
    existing_like = MessageLike.query.filter_by(
        user_id=user_id,
        message_id=message_id
    ).first()
    
    if existing_like:
        # 取消点赞
        db.session.delete(existing_like)
        message.like_count = max(0, message.like_count - 1)
        is_liked = False
        action = '取消点赞'
    else:
        # 添加点赞
        new_like = MessageLike(
            user_id=user_id,
            message_id=message_id
        )
        db.session.add(new_like)
        message.like_count += 1
        is_liked = True
        action = '点赞'
    
    db.session.commit()
    
    return jsonify({
        'message': f'{action}成功',
        'is_liked': is_liked,
        'like_count': message.like_count
    }), 200

# 获取留言详情
@main.route('/api/messages/<int:message_id>', methods=['GET'])
def get_message_detail(message_id):
    message = Message.query.get_or_404(message_id)
    
    if message.status != 'published':
        return jsonify({'message': '留言不存在或未发布'}), 404
    
    # 获取留言的图片
    images = [{
        'id': img.id,
        'image_url': url_for('static', filename=f'uploads/{img.image_url}'),
        'name': img.image_name
    } for img in message.images]
    
    # 检查当前用户是否已点赞
    is_liked = False
    if 'user_id' in session:
        like = MessageLike.query.filter_by(
            user_id=session['user_id'],
            message_id=message_id
        ).first()
        is_liked = like is not None
    
    message_data = {
        'id': message.id,
        'content': message.content,
        'is_pinned': message.is_pinned,
        'like_count': message.like_count,
        'comment_count': message.comment_count,
        'created_at': message.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        'user': {
            'id': message.user.id,
            'username': message.user.username,
            'avatar_url': message.user.avatar_url
        },
        'images': images,
        'user_liked': is_liked
    }
    
    return jsonify(message_data)

# ==================== 留言评论相关API ====================

# 获取留言的评论
@main.route('/api/messages/<int:message_id>/comments', methods=['GET'])
def get_message_comments(message_id):
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    # 检查留言是否存在
    message = Message.query.get_or_404(message_id)
    if message.status != 'published':
        return jsonify({'message': '留言不存在或未发布'}), 404
    
    # 分页查询评论
    comments = MessageComment.query.filter_by(
        message_id=message_id
    ).order_by(
        MessageComment.created_at.asc()
    ).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    result = []
    for comment in comments.items:
        comment_data = {
            'id': comment.id,
            'content': comment.content,
            'created_at': comment.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'user': {
                'id': comment.user.id,
                'username': comment.user.username,
                'avatar_url': comment.user.get_avatar_url()
            }
        }
        
        # 如果是回复评论，添加父评论信息
        if comment.parent_id:
            parent_comment = MessageComment.query.get(comment.parent_id)
            if parent_comment:
                comment_data['parent'] = {
                    'id': parent_comment.id,
                    'content': parent_comment.content[:50] + '...' if len(parent_comment.content) > 50 else parent_comment.content,
                    'user': {
                        'username': parent_comment.user.username
                    }
                }
        
        result.append(comment_data)
    
    return jsonify(result)

# 发布留言评论
@main.route('/api/messages/<int:message_id>/comments', methods=['POST'])
def create_message_comment(message_id):
    # 检查用户是否登录
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    # 检查留言是否存在
    message = Message.query.get_or_404(message_id)
    if message.status != 'published':
        return jsonify({'message': '留言不存在或未发布'}), 404
    
    data = request.get_json()
    content = data.get('content', '').strip()
    parent_id = data.get('parent_id')
    
    if not content:
        return jsonify({'message': '评论内容不能为空'}), 400
    
    # 内容审核
    is_valid, filter_result = filter_content(content)
    if not is_valid:
        return jsonify({'message': filter_result}), 400
    
    # 如果是回复评论，检查父评论是否存在
    if parent_id:
        parent_comment = MessageComment.query.filter_by(
            id=parent_id,
            message_id=message_id
        ).first()
        if not parent_comment:
            return jsonify({'message': '回复的评论不存在'}), 400
    
    # 创建新评论
    new_comment = MessageComment(
        message_id=message_id,
        user_id=session['user_id'],
        content=content,
        parent_id=parent_id
    )
    
    db.session.add(new_comment)
    
    # 更新留言的评论数量
    message.comment_count += 1
    
    db.session.commit()
    
    # 返回新创建的评论信息
    comment_data = {
        'id': new_comment.id,
        'content': new_comment.content,
        'created_at': new_comment.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        'user': {
            'id': new_comment.user.id,
            'username': new_comment.user.username,
            'avatar_url': new_comment.user.get_avatar_url()
        }
    }
    
    # 如果是回复评论，添加父评论信息
    if new_comment.parent_id:
        parent_comment = MessageComment.query.get(new_comment.parent_id)
        if parent_comment:
            comment_data['parent'] = {
                'id': parent_comment.id,
                'content': parent_comment.content[:50] + '...' if len(parent_comment.content) > 50 else parent_comment.content,
                'user': {
                    'username': parent_comment.user.username
                }
            }
    
    return jsonify({
        'message': '评论发布成功',
        'comment': comment_data
    }), 201

# 删除留言评论
@main.route('/api/messages/<int:message_id>/comments/<int:comment_id>', methods=['DELETE'])
def delete_message_comment(message_id, comment_id):
    # 检查用户是否登录
    if 'user_id' not in session:
        return jsonify({'message': '请先登录'}), 401
    
    comment = MessageComment.query.filter_by(
        id=comment_id,
        message_id=message_id
    ).first_or_404()
    
    # 检查权限：只有评论作者或管理员可以删除
    if comment.user_id != session['user_id'] and session.get('role') != 'admin':
        return jsonify({'message': '没有权限删除此评论'}), 403
    
    # 获取留言对象
    message = Message.query.get(message_id)
    
    # 删除评论
    db.session.delete(comment)
    
    # 更新留言的评论数量
    if message:
        message.comment_count = max(0, message.comment_count - 1)
    
    db.session.commit()
    
    return jsonify({'message': '评论删除成功'}), 200

# ==================== 管理员相关API ====================

# 获取所有留言（管理员功能）
@main.route('/api/admin/messages', methods=['GET'])
def get_admin_messages():
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    # 获取所有留言（包括草稿），置顶的留言优先显示
    messages = Message.query.order_by(
        Message.is_pinned.desc(),
        Message.created_at.desc()
    ).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    result = []
    for message in messages.items:
        # 获取留言的图片
        images = [{
            'id': img.id,
            'image_url': url_for('static', filename=f'uploads/{img.image_url}'),
            'name': img.image_name
        } for img in message.images]
        
        message_data = {
            'id': message.id,
            'content': message.content,
            'status': message.status,
            'is_pinned': message.is_pinned,
            'like_count': message.like_count,
            'comment_count': message.comment_count,
            'created_at': message.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'user': {
                'id': message.user.id,
                'username': message.user.username,
                'avatar_url': message.user.get_avatar_url()
            },
            'images': images
        }
        result.append(message_data)
    
    return jsonify(result)

# 获取关键词过滤列表（管理员功能）
@main.route('/api/admin/keyword-filters', methods=['GET'])
def get_keyword_filters():
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    filters = KeywordFilter.query.order_by(KeywordFilter.created_at.desc()).all()
    
    result = []
    for filter_rule in filters:
        result.append({
            'id': filter_rule.id,
            'keyword': filter_rule.keyword,
            'is_active': filter_rule.is_active,
            'created_at': filter_rule.created_at.strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify({'filters': result})

# 添加关键词过滤（管理员功能）
@main.route('/api/admin/keyword-filters', methods=['POST'])
def add_keyword_filter():
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    data = request.get_json()
    keyword = data.get('keyword', '').strip()
    
    if not keyword:
        return jsonify({'message': '关键词不能为空'}), 400
    
    # 检查关键词是否已存在
    existing_filter = KeywordFilter.query.filter_by(keyword=keyword).first()
    if existing_filter:
        return jsonify({'message': '该关键词已存在'}), 400
    
    # 创建新的关键词过滤规则
    new_filter = KeywordFilter(
        keyword=keyword,
        is_active=True
    )
    
    db.session.add(new_filter)
    db.session.commit()
    
    return jsonify({
        'message': '关键词过滤规则添加成功',
        'filter': {
            'id': new_filter.id,
            'keyword': new_filter.keyword,
            'is_active': new_filter.is_active,
            'created_at': new_filter.created_at.strftime('%Y-%m-%d %H:%M:%S')
        }
    }), 201

# 删除关键词过滤（管理员功能）
@main.route('/api/admin/keyword-filters/<int:filter_id>', methods=['DELETE'])
def delete_keyword_filter(filter_id):
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    filter_rule = KeywordFilter.query.get_or_404(filter_id)
    
    db.session.delete(filter_rule)
    db.session.commit()
    
    return jsonify({'message': '关键词过滤规则删除成功'}), 200

# 切换关键词过滤状态（管理员功能）
@main.route('/api/admin/keyword-filters/<int:filter_id>/toggle', methods=['POST'])
def toggle_keyword_filter(filter_id):
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    filter_rule = KeywordFilter.query.get_or_404(filter_id)
    filter_rule.is_active = not filter_rule.is_active
    
    db.session.commit()
    
    status = '启用' if filter_rule.is_active else '禁用'
    return jsonify({
        'message': f'关键词过滤规则{status}成功',
        'is_active': filter_rule.is_active
    }), 200

# ==================== 用户管理相关API ====================

# 获取用户列表（管理员功能）
@main.route('/api/admin/users', methods=['GET'])
def get_users():
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        search = request.args.get('search', '').strip()
        role_filter = request.args.get('role', '').strip()
        status_filter = request.args.get('status', '').strip()
        
        # 构建查询
        query = User.query
        
        # 搜索过滤
        if search:
            query = query.filter(
                db.or_(
                    User.username.contains(search),
                    User.email.contains(search)
                )
            )
        
        # 角色过滤
        if role_filter:
            query = query.filter(User.role == role_filter)
        
        # 状态过滤
        if status_filter == 'active':
            query = query.filter(User.is_active == True)
        elif status_filter == 'inactive':
            query = query.filter(User.is_active == False)
        
        # 分页查询
        users = query.order_by(User.created_at.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        result = []
        for user in users.items:
            # 获取用户统计数据
            timeline_count = TimelineEntry.query.filter_by(user_id=user.id).count() if hasattr(TimelineEntry, 'user_id') else 0
            message_count = Message.query.filter_by(user_id=user.id).count()
            comment_count = MessageComment.query.filter_by(user_id=user.id).count()
            
            user_data = {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'role': user.role,
                'is_active': user.is_active,
                'avatar_url': user.get_avatar_url(),
                'bio': user.bio,
                'last_login': user.last_login.strftime('%Y-%m-%d %H:%M:%S') if user.last_login else None,
                'login_count': user.login_count or 0,
                'created_at': user.created_at.strftime('%Y-%m-%d %H:%M:%S') if user.created_at else None,
                'updated_at': user.updated_at.strftime('%Y-%m-%d %H:%M:%S') if user.updated_at else None,
                'stats': {
                    'timeline_count': timeline_count,
                    'message_count': message_count,
                    'comment_count': comment_count
                }
            }
            result.append(user_data)
        
        return jsonify({
            'users': result,
            'pagination': {
                'page': users.page,
                'pages': users.pages,
                'per_page': users.per_page,
                'total': users.total,
                'has_next': users.has_next,
                'has_prev': users.has_prev
            }
        }), 200
        
    except Exception as e:

        return jsonify({'message': f'获取用户列表失败: {str(e)}'}), 500

# 获取用户详情（管理员功能）
@main.route('/api/admin/users/<int:user_id>', methods=['GET'])
def get_user_detail(user_id):
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        user = User.query.get_or_404(user_id)
        
        # 获取用户活动记录
        from sqlalchemy import text
        activities = db.session.execute(text("""
            SELECT action_type, description, ip_address, created_at
            FROM user_activities 
            WHERE user_id = :user_id 
            ORDER BY created_at DESC 
            LIMIT 50
        """), {'user_id': user_id}).fetchall()
        
        activity_list = []
        for activity in activities:
            activity_list.append({
                'action_type': activity[0],
                'description': activity[1],
                'ip_address': activity[2],
                'created_at': activity[3]
            })
        
        # 获取用户内容统计
        timeline_count = TimelineEntry.query.filter_by(user_id=user.id).count() if hasattr(TimelineEntry, 'user_id') else 0
        message_count = Message.query.filter_by(user_id=user.id).count()
        comment_count = MessageComment.query.filter_by(user_id=user.id).count()
        
        # 获取用户权限
        permissions = db.session.execute(text("""
            SELECT p.name, p.description, up.granted_at
            FROM user_permissions up
            JOIN permissions p ON up.permission_id = p.id
            WHERE up.user_id = :user_id
        """), {'user_id': user_id}).fetchall()
        
        permission_list = []
        for perm in permissions:
            permission_list.append({
                'name': perm[0],
                'description': perm[1],
                'granted_at': perm[2]
            })
        
        user_data = {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'role': user.role,
            'is_active': user.is_active,
            'avatar_url': user.get_avatar_url(),
            'bio': user.bio,
            'last_login': user.last_login.strftime('%Y-%m-%d %H:%M:%S') if user.last_login else None,
            'login_count': user.login_count or 0,
            'created_at': user.created_at.strftime('%Y-%m-%d %H:%M:%S') if user.created_at else None,
            'updated_at': user.updated_at.strftime('%Y-%m-%d %H:%M:%S') if user.updated_at else None,
            'stats': {
                'timeline_count': timeline_count,
                'message_count': message_count,
                'comment_count': comment_count
            },
            'activities': activity_list,
            'permissions': permission_list
        }
        
        return jsonify(user_data), 200
        
    except Exception as e:

        return jsonify({'message': f'获取用户详情失败: {str(e)}'}), 500

# 更新用户信息（管理员功能）
@main.route('/api/admin/users/<int:user_id>', methods=['PUT'])
def update_user(user_id):
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        user = User.query.get_or_404(user_id)
        data = request.get_json()
        
        # 更新用户信息
        if 'username' in data:
            # 检查用户名是否已存在
            existing_user = User.query.filter(User.username == data['username'], User.id != user_id).first()
            if existing_user:
                return jsonify({'message': '用户名已存在'}), 400
            user.username = data['username']
        
        if 'email' in data:
            # 检查邮箱是否已存在
            existing_user = User.query.filter(User.email == data['email'], User.id != user_id).first()
            if existing_user:
                return jsonify({'message': '邮箱已存在'}), 400
            user.email = data['email']
        
        if 'role' in data:
            user.role = data['role']
        
        if 'is_active' in data:
            user.is_active = data['is_active']
        
        if 'bio' in data:
            user.bio = data['bio']
        
        if 'avatar_url' in data:
            user.avatar_url = data['avatar_url']
        
        # 更新时间戳
        user.updated_at = datetime.now()
        
        db.session.commit()
        
        # 记录管理员操作
        from sqlalchemy import text
        db.session.execute(text("""
            INSERT INTO user_activities (user_id, action_type, description, ip_address)
            VALUES (:user_id, 'admin_update', :description, :ip_address)
        """), {
            'user_id': user_id,
            'description': f'管理员更新了用户信息',
            'ip_address': request.remote_addr
        })
        db.session.commit()
        
        return jsonify({'message': '用户信息更新成功'}), 200
        
    except Exception as e:

        return jsonify({'message': f'更新用户信息失败: {str(e)}'}), 500

# 切换用户状态（管理员功能）
@main.route('/api/admin/users/<int:user_id>/toggle-status', methods=['POST'])
def toggle_user_status(user_id):
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        user = User.query.get_or_404(user_id)
        
        # 不能禁用管理员账户
        if user.role == 'admin':
            return jsonify({'message': '不能禁用管理员账户'}), 400
        
        # 切换状态
        user.is_active = not user.is_active
        user.updated_at = datetime.now()
        
        db.session.commit()
        
        # 记录管理员操作
        from sqlalchemy import text
        action = '启用' if user.is_active else '禁用'
        db.session.execute(text("""
            INSERT INTO user_activities (user_id, action_type, description, ip_address)
            VALUES (:user_id, 'status_change', :description, :ip_address)
        """), {
            'user_id': user_id,
            'description': f'管理员{action}了用户账户',
            'ip_address': request.remote_addr
        })
        db.session.commit()
        
        return jsonify({
            'message': f'用户账户{action}成功',
            'is_active': user.is_active
        }), 200
        
    except Exception as e:

        return jsonify({'message': f'切换用户状态失败: {str(e)}'}), 500

# 批量操作用户（管理员功能）
@main.route('/api/admin/users/batch', methods=['POST'])
def batch_user_operations():
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        data = request.get_json()
        user_ids = data.get('user_ids', [])
        action = data.get('action', '')
        
        if not user_ids or not action:
            return jsonify({'message': '参数不完整'}), 400
        
        # 获取用户列表
        users = User.query.filter(User.id.in_(user_ids)).all()
        
        if not users:
            return jsonify({'message': '未找到指定用户'}), 404
        
        success_count = 0
        error_messages = []
        
        for user in users:
            try:
                if action == 'activate':
                    user.is_active = True
                    action_desc = '批量启用用户账户'
                elif action == 'deactivate':
                    # 不能禁用管理员账户
                    if user.role == 'admin':
                        error_messages.append(f'不能禁用管理员账户: {user.username}')
                        continue
                    user.is_active = False
                    action_desc = '批量禁用用户账户'
                elif action == 'delete':
                    # 不能删除管理员账户
                    if user.role == 'admin':
                        error_messages.append(f'不能删除管理员账户: {user.username}')
                        continue
                    # 删除用户相关数据
                    MessageComment.query.filter_by(user_id=user.id).delete()
                    MessageLike.query.filter_by(user_id=user.id).delete()
                    Message.query.filter_by(user_id=user.id).delete()
                    db.session.delete(user)
                    action_desc = '批量删除用户账户'
                else:
                    return jsonify({'message': '不支持的操作类型'}), 400
                
                if action != 'delete':
                    user.updated_at = datetime.now()
                
                # 记录操作日志
                if action != 'delete':
                    from sqlalchemy import text
                    db.session.execute(text("""
                        INSERT INTO user_activities (user_id, action_type, description, ip_address)
                        VALUES (:user_id, 'batch_operation', :description, :ip_address)
                    """), {
                        'user_id': user.id,
                        'description': action_desc,
                        'ip_address': request.remote_addr
                    })
                
                success_count += 1
                
            except Exception as e:
                error_messages.append(f'处理用户 {user.username} 时出错: {str(e)}')
        
        db.session.commit()
        
        result = {
            'message': f'批量操作完成，成功处理 {success_count} 个用户',
            'success_count': success_count,
            'total_count': len(user_ids)
        }
        
        if error_messages:
            result['errors'] = error_messages
        
        return jsonify(result), 200
        
    except Exception as e:

        return jsonify({'message': f'批量操作失败: {str(e)}'}), 500



# 获取用户权限列表（管理员功能）
@main.route('/api/admin/permissions', methods=['GET'])
def get_permissions():
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        from sqlalchemy import text
        
        # 获取所有权限
        permissions = db.session.execute(text("""
            SELECT id, name, description, category
            FROM permissions
            ORDER BY category, name
        """)).fetchall()
        
        permission_list = [{
            'id': row.id,
            'name': row.name,
            'description': row.description,
            'category': row.category
        } for row in permissions]
        
        return jsonify({'permissions': permission_list}), 200
        
    except Exception as e:

        return jsonify({'message': f'获取权限列表失败: {str(e)}'}), 500

# 更新用户权限（管理员功能）
@main.route('/api/admin/users/<int:user_id>/permissions', methods=['PUT'])
def update_user_permissions(user_id):
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        user = User.query.get_or_404(user_id)
        data = request.get_json()
        permission_ids = data.get('permission_ids', [])
        
        from sqlalchemy import text
        
        # 删除用户现有权限
        db.session.execute(text("""
            DELETE FROM user_permissions WHERE user_id = :user_id
        """), {'user_id': user_id})
        
        # 添加新权限
        for permission_id in permission_ids:
            db.session.execute(text("""
                INSERT INTO user_permissions (user_id, permission_id)
                VALUES (:user_id, :permission_id)
            """), {
                'user_id': user_id,
                'permission_id': permission_id
            })
        
        db.session.commit()
        
        # 记录管理员操作
        db.session.execute(text("""
            INSERT INTO user_activities (user_id, action_type, description, ip_address)
            VALUES (:user_id, 'permission_update', :description, :ip_address)
        """), {
            'user_id': user_id,
            'description': f'管理员更新了用户权限',
            'ip_address': request.remote_addr
        })
        db.session.commit()
        
        return jsonify({'message': '用户权限更新成功'}), 200
        
    except Exception as e:

        return jsonify({'message': f'更新用户权限失败: {str(e)}'}), 500

# 删除用户（管理员功能）
@main.route('/api/admin/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    # 检查是否为管理员
    if 'user_id' not in session or session.get('role') != 'admin':
        return jsonify({'message': '没有权限执行此操作'}), 403
    
    try:
        user = User.query.get_or_404(user_id)
        
        # 不能删除管理员账户
        if user.role == 'admin':
            return jsonify({'message': '不能删除管理员账户'}), 400
        
        # 删除用户相关数据
        from sqlalchemy import text
        
        # 删除用户权限
        db.session.execute(text("""
            DELETE FROM user_permissions WHERE user_id = :user_id
        """), {'user_id': user_id})
        
        # 删除用户活动记录
        db.session.execute(text("""
            DELETE FROM user_activities WHERE user_id = :user_id
        """), {'user_id': user_id})
        
        # 删除用户相关内容
        MessageComment.query.filter_by(user_id=user_id).delete()
        MessageLike.query.filter_by(user_id=user_id).delete()
        Message.query.filter_by(user_id=user_id).delete()
        Comment.query.filter_by(user_id=user_id).delete()
        TimelineEntry.query.filter_by(user_id=user_id).delete()
        TimeCapsule.query.filter_by(user_id=user_id).delete()
        
        # 删除用户
        db.session.delete(user)
        db.session.commit()
        
        return jsonify({'message': '用户删除成功'}), 200
        
    except Exception as e:

        return jsonify({'message': f'删除用户失败: {str(e)}'}), 500